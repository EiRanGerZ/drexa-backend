-- 000001_init.down.sql
-- Reverse of core schemas

DROP TABLE IF EXISTS crypto_addresses CASCADE;

DROP INDEX IF EXISTS idx_trades_executed_at;
DROP INDEX IF EXISTS idx_trades_pair_id;
DROP TABLE IF EXISTS trades CASCADE;

DROP INDEX IF EXISTS idx_orders_status;
DROP INDEX IF EXISTS idx_orders_pair_id;
DROP INDEX IF EXISTS idx_orders_user_id;
DROP TABLE IF EXISTS orders CASCADE;

DROP INDEX IF EXISTS idx_candles_pair_interval;
DROP TABLE IF EXISTS candles CASCADE;

DROP INDEX IF EXISTS idx_price_snapshots_time;
DROP INDEX IF EXISTS idx_price_snapshots_pair_id;
DROP TABLE IF EXISTS price_snapshots CASCADE;

DROP TABLE IF EXISTS trading_pairs CASCADE;
DROP TABLE IF EXISTS coins CASCADE;

DROP INDEX IF EXISTS idx_withdrawal_requests_wallet_id;
DROP INDEX IF EXISTS idx_withdrawal_requests_user_id;
DROP TABLE IF EXISTS withdrawal_requests CASCADE;

DROP INDEX IF EXISTS idx_deposit_requests_wallet_id;
DROP INDEX IF EXISTS idx_deposit_requests_user_id;
DROP TABLE IF EXISTS deposit_requests CASCADE;

DROP INDEX IF EXISTS idx_transactions_ref_id;
DROP INDEX IF EXISTS idx_transactions_user_id;
DROP INDEX IF EXISTS idx_transactions_wallet_id;
DROP TABLE IF EXISTS transactions CASCADE;

DROP INDEX IF EXISTS idx_wallets_deleted_at;
DROP INDEX IF EXISTS idx_wallets_currency;
DROP INDEX IF EXISTS idx_wallets_user_id;
DROP TABLE IF EXISTS wallets CASCADE;

DROP INDEX IF EXISTS idx_kyc_submissions_status;
DROP INDEX IF EXISTS idx_kyc_submissions_user_id;
DROP TABLE IF EXISTS kyc_submissions CASCADE;

DROP TABLE IF EXISTS otp_codes CASCADE;

DROP INDEX IF EXISTS idx_refresh_tokens_user_id;
DROP TABLE IF EXISTS refresh_tokens CASCADE;

DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS p2p_disputes CASCADE;
DROP TABLE IF EXISTS p2p_orders CASCADE;
DROP TABLE IF EXISTS p2p_advertisements CASCADE;
