-- FCM push-token registry. The upsert-on-register pattern reassigns
-- ownership when the same token lands on a new user (device swaps,
-- factory reset, multi-account). Logout deletes the row.

-- name: UpsertPushToken :exec
INSERT INTO push_tokens (fcm_token, user_id, platform)
VALUES ($1, $2, $3)
ON CONFLICT (fcm_token) DO UPDATE
    SET user_id    = EXCLUDED.user_id,
        platform   = EXCLUDED.platform,
        updated_at = now();

-- name: DeletePushToken :exec
DELETE FROM push_tokens
WHERE fcm_token = $1
  AND user_id = $2;

-- name: ListPushTokensForUser :many
SELECT fcm_token, platform
FROM push_tokens
WHERE user_id = $1
ORDER BY updated_at DESC;

-- name: DeletePushTokenByValue :exec
DELETE FROM push_tokens WHERE fcm_token = $1;
