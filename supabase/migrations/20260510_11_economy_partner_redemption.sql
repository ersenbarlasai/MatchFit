-- ==============================================================================
-- MATCHFIT ECONOMY & PARTNER REDEMPTION INTEGRATION
-- @EconomyEngine & @PartnerCatalog Unified Workflow
-- ==============================================================================

-- 1. ADD MISSING COLUMNS TO REDEMPTION ATTEMPTS
ALTER TABLE public.redemption_attempts 
  ADD COLUMN IF NOT EXISTS partner_id UUID,
  ADD COLUMN IF NOT EXISTS cost_points INTEGER;

-- 2. UPDATED REDEMPTION RPC (The Unified Contract)
CREATE OR REPLACE FUNCTION public.attempt_reward_redemption(
    p_user_id UUID,
    p_reward_id UUID,
    p_amount INTEGER, -- Client's estimated amount (Catalog is the source of truth)
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_balance INTEGER;
    v_trust_score INTEGER;
    v_risk_level TEXT;
    
    v_catalog_reward_id UUID;
    v_partner_id UUID;
    v_cost_points INTEGER;
    v_stock_remaining INTEGER;
    v_reward_status TEXT;
    
    v_status TEXT := 'approved';
    v_reason TEXT := '';
    v_redemption_id UUID;
    
    v_inventory_idemp_key TEXT;
    v_ledger_idemp_key TEXT;
    v_reserve_success BOOLEAN;
BEGIN
    -- 1. Idempotency Check (Redemption Level)
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id, status, rejection_reason INTO v_redemption_id, v_status, v_reason
        FROM public.redemption_attempts WHERE idempotency_key = p_idempotency_key;
        IF v_redemption_id IS NOT NULL THEN
            RETURN jsonb_build_object('id', v_redemption_id, 'status', v_status, 'reason', v_reason);
        END IF;
    END IF;

    -- 2. Fetch Reward Data from @PartnerCatalog (Source of Truth)
    SELECT id, partner_id, cost_points, stock_remaining, status 
    INTO v_catalog_reward_id, v_partner_id, v_cost_points, v_stock_remaining, v_reward_status
    FROM public.get_reward_catalog_item(p_reward_id);

    -- 3. Initial Eligibility Checks
    IF v_catalog_reward_id IS NULL THEN
        v_status := 'rejected'; v_reason := 'Ödül kataloğu öğesi bulunamadı.';
    ELSIF v_reward_status != 'active' THEN
        v_status := 'rejected'; v_reason := 'Bu ödül şu an aktif değil veya süresi dolmuş.';
    ELSIF v_stock_remaining IS NOT NULL AND v_stock_remaining <= 0 THEN
        v_status := 'rejected'; v_reason := 'Ödül stoğu tükendi.';
    END IF;

    -- 4. User Eligibility Checks (Trust, Fraud, Balance)
    IF v_status = 'approved' THEN
        SELECT balance INTO v_balance FROM public.user_mf_balance WHERE user_id = p_user_id;
        SELECT trust_score INTO v_trust_score FROM public.profiles WHERE id = p_user_id;
        SELECT risk_level INTO v_risk_level FROM public.risk_scores WHERE user_id = p_user_id;
        v_risk_level := COALESCE(v_risk_level, 'clear');

        IF v_balance IS NULL OR v_balance < v_cost_points THEN
            v_status := 'rejected'; v_reason := 'Yetersiz MF Points bakiyesi. Gerekli: ' || v_cost_points;
        ELSIF v_trust_score < 40 THEN
            v_status := 'rejected'; v_reason := 'Güven puanı ödül alımı için çok düşük (Min: 40).';
        ELSIF v_risk_level IN ('blocked', 'high_risk') THEN
            v_status := 'rejected'; v_reason := 'Hesap güvenliği kısıtlamaları nedeniyle işlem yapılamıyor.';
        END IF;
    END IF;

    -- 5. Atomic Execution (Stock Reservation + Ledger Update)
    IF v_status = 'approved' THEN
        -- Standardized Idempotency Keys for Sub-actions
        v_inventory_idemp_key := 'redemption:' || p_user_id || ':' || p_reward_id || ':' || COALESCE(p_idempotency_key, 'anon') || ':inventory';
        v_ledger_idemp_key := 'redemption:' || p_user_id || ':' || p_reward_id || ':' || COALESCE(p_idempotency_key, 'anon') || ':ledger';

        -- A. Reserve Stock in @PartnerCatalog
        v_reserve_success := public.reserve_reward_inventory(p_reward_id, v_inventory_idemp_key);
        
        IF NOT v_reserve_success THEN
            v_status := 'rejected'; v_reason := 'Stok rezervasyonu sırasında bir hata oluştu.';
        ELSE
            -- B. Deduct Points in @EconomyEngine
            BEGIN
                PERFORM public.add_mf_points(p_user_id, -v_cost_points, 'redemption', 'Reward Redemption: ' || v_catalog_reward_id, v_ledger_idemp_key);
            EXCEPTION WHEN OTHERS THEN
                -- Critical: If points deduction fails, we should ideally rollback stock.
                -- In this atomic flow, the entire transaction will rollback if any exception is unhandled.
                RAISE EXCEPTION 'Ekonomi işlemi başarısız oldu, işlem iptal ediliyor: %', SQLERRM;
            END;
        END IF;
    END IF;

    -- 6. Log Attempt
    INSERT INTO public.redemption_attempts (
        user_id, reward_id, partner_id, amount, cost_points, status, rejection_reason, risk_level, idempotency_key, metadata
    )
    VALUES (
        p_user_id, p_reward_id, v_partner_id, COALESCE(p_amount, v_cost_points), v_cost_points, v_status, v_reason, v_risk_level, p_idempotency_key,
        jsonb_build_object(
            'inventory_key', v_inventory_idemp_key, 
            'ledger_key', v_ledger_idemp_key,
            'source', 'partner_catalog_integrated'
        )
    )
    RETURNING id INTO v_redemption_id;

    -- 7. Notification Delivery
    IF v_status = 'approved' THEN
        PERFORM public.create_notification_request(
            p_user_id,
            'redemption_success',
            'Tebrikler! Ödül Alındı',
            'Ödül talebiniz onaylandı ve MF puanlarınız düşüldü. Detaylar için cüzdanınızı kontrol edin.',
            NULL,
            jsonb_build_object('redemption_id', v_redemption_id, 'reward_id', p_reward_id),
            'notif:red_success:' || v_redemption_id
        );
    ELSE
        PERFORM public.create_notification_request(
            p_user_id,
            'redemption_rejected',
            'Ödül Talebi Başarısız',
            'Talebiniz reddedildi: ' || v_reason,
            NULL,
            jsonb_build_object('redemption_id', v_redemption_id, 'reason', v_reason),
            'notif:red_reject:' || v_redemption_id
        );
    END IF;

    RETURN jsonb_build_object(
        'id', v_redemption_id, 
        'status', v_status, 
        'reason', v_reason, 
        'cost_points', v_cost_points,
        'partner_id', v_partner_id
    );
END;
$$;
