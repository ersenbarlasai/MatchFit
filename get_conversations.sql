CREATE OR REPLACE FUNCTION get_conversations(p_user_id UUID)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    avatar_url TEXT,
    last_message TEXT,
    last_message_time TIMESTAMPTZ,
    unread_count INT
) AS $$
BEGIN
    RETURN QUERY
    WITH recent_messages AS (
        SELECT 
            CASE 
                WHEN sender_id = p_user_id THEN receiver_id 
                ELSE sender_id 
            END as peer_id,
            content,
            created_at,
            sender_id,
            is_read,
            ROW_NUMBER() OVER (
                PARTITION BY CASE WHEN sender_id = p_user_id THEN receiver_id ELSE sender_id END 
                ORDER BY created_at DESC
            ) as rn
        FROM direct_messages
        WHERE sender_id = p_user_id OR receiver_id = p_user_id
    ),
    unread_counts AS (
        SELECT 
            sender_id as peer_id,
            COUNT(*) as count
        FROM direct_messages
        WHERE receiver_id = p_user_id AND is_read = false
        GROUP BY sender_id
    )
    SELECT 
        p.id as user_id,
        p.full_name,
        p.avatar_url,
        rm.content as last_message,
        rm.created_at as last_message_time,
        COALESCE(uc.count, 0)::INT as unread_count
    FROM recent_messages rm
    JOIN profiles p ON p.id = rm.peer_id
    LEFT JOIN unread_counts uc ON uc.peer_id = rm.peer_id
    WHERE rm.rn = 1
    ORDER BY rm.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
