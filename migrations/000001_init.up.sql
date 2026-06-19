-- 000001_init.up.sql
-- Core schemas for auth, kyc, wallet, market, orders, crypto_addresses

-- 1. Auth
CREATE TABLE IF NOT EXISTS users (
    user_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email            TEXT NOT NULL UNIQUE,
    phone            TEXT NOT NULL UNIQUE,
    password_hash    TEXT NOT NULL,
    trading_pin_hash TEXT NOT NULL DEFAULT '',
    role             TEXT NOT NULL DEFAULT 'user'
                         CHECK (role IN ('user', 'merchant', 'admin')),
    kyc_level        INTEGER NOT NULL DEFAULT 0,
    two_fa_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
    two_fa_secret    TEXT NOT NULL DEFAULT '',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    token_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    user_agent TEXT NOT NULL DEFAULT '',
    ip_address TEXT NOT NULL DEFAULT '',
    expired_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);

CREATE TABLE IF NOT EXISTS otp_codes (
    otp_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key        TEXT NOT NULL UNIQUE,
    code_hash  TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. KYC
CREATE TABLE IF NOT EXISTS kyc_submissions (
    submission_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status           TEXT NOT NULL DEFAULT 'pending'
                         CHECK (status IN ('pending', 'approved', 'rejected')),
    full_name        TEXT NOT NULL,
    id_number        TEXT NOT NULL,   -- AES-256 encrypted NIK; never store plaintext
    id_type          TEXT NOT NULL,   -- e.g. 'ktp', 'passport'
    file_url         TEXT NOT NULL,   -- encrypted object storage path
    selfie_url       TEXT NOT NULL,   -- encrypted object storage path
    rejection_reason TEXT,
    submitted_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_by      TEXT NOT NULL DEFAULT '',
    reviewed_at      TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_kyc_submissions_user_id  ON kyc_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_kyc_submissions_status   ON kyc_submissions(status);

-- 3. Wallet
CREATE TABLE IF NOT EXISTS wallets (
    wallet_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    currency    TEXT NOT NULL,
    balance     BIGINT NOT NULL DEFAULT 0,
    locked      BIGINT NOT NULL DEFAULT 0,
    status      TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'suspended', 'closed')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ,
    UNIQUE (user_id, currency)
);
CREATE INDEX IF NOT EXISTS idx_wallets_user_id    ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallets_currency   ON wallets(currency);
CREATE INDEX IF NOT EXISTS idx_wallets_deleted_at ON wallets(deleted_at);

CREATE TABLE IF NOT EXISTS transactions (
    tx_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id      UUID NOT NULL REFERENCES wallets(wallet_id),
    user_id        UUID NOT NULL REFERENCES users(user_id),
    type           TEXT NOT NULL CHECK (type IN (
                       'deposit', 'withdrawal', 'transfer', 'fee', 'reversal')),
    status         TEXT NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending', 'completed', 'failed', 'reversed')),
    amount         BIGINT NOT NULL,
    balance_before BIGINT NOT NULL DEFAULT 0,
    balance_after  BIGINT NOT NULL DEFAULT 0,
    currency       TEXT NOT NULL,
    ref_id         TEXT NOT NULL DEFAULT '',
    description    TEXT NOT NULL DEFAULT '',
    metadata       TEXT NOT NULL DEFAULT '',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_transactions_wallet_id ON transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id   ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_ref_id    ON transactions(ref_id);

CREATE TABLE IF NOT EXISTS deposit_requests (
    deposit_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    wallet_id    UUID NOT NULL REFERENCES wallets(wallet_id),
    amount       BIGINT NOT NULL,
    currency     TEXT NOT NULL,
    provider     TEXT NOT NULL,
    provider_ref TEXT NOT NULL UNIQUE,
    status       TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'completed', 'failed', 'reversed')),
    expires_at   TIMESTAMPTZ NOT NULL,
    confirmed_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_deposit_requests_user_id   ON deposit_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_deposit_requests_wallet_id ON deposit_requests(wallet_id);

CREATE TABLE IF NOT EXISTS withdrawal_requests (
    withdrawal_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    wallet_id        UUID NOT NULL REFERENCES wallets(wallet_id),
    amount           BIGINT NOT NULL,
    currency         TEXT NOT NULL,
    bank_code        TEXT NOT NULL DEFAULT '',
    account_number   TEXT NOT NULL DEFAULT '',
    account_name     TEXT NOT NULL DEFAULT '',
    status           TEXT NOT NULL DEFAULT 'pending'
                         CHECK (status IN ('pending', 'completed', 'failed', 'reversed')),
    provider_ref     TEXT NOT NULL DEFAULT '',
    rejection_reason TEXT NOT NULL DEFAULT '',
    processed_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_user_id   ON withdrawal_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_wallet_id ON withdrawal_requests(wallet_id);

-- 4. Market
CREATE TABLE IF NOT EXISTS coins (
    coin_id    TEXT PRIMARY KEY,
    symbol     TEXT NOT NULL UNIQUE,
    name       TEXT NOT NULL,
    decimals   INTEGER NOT NULL DEFAULT 18,
    network    TEXT NOT NULL,
    status     TEXT NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'suspended')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trading_pairs (
    pair_id               TEXT PRIMARY KEY,
    base_coin             TEXT NOT NULL REFERENCES coins(coin_id),
    quote_coin            TEXT NOT NULL REFERENCES coins(coin_id),
    status                TEXT NOT NULL DEFAULT 'active'
                              CHECK (status IN ('active', 'suspended')),
    min_order_size        NUMERIC(36, 18) NOT NULL DEFAULT 0,
    price_decimal_places  INTEGER NOT NULL DEFAULT 2,
    UNIQUE (base_coin, quote_coin)
);

CREATE TABLE IF NOT EXISTS price_snapshots (
    snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pair_id     TEXT NOT NULL REFERENCES trading_pairs(pair_id),
    price       NUMERIC(36, 18) NOT NULL,
    change_24h  NUMERIC(10, 4) NOT NULL DEFAULT 0,
    volume_24h  NUMERIC(36, 18) NOT NULL DEFAULT 0,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_price_snapshots_pair_id  ON price_snapshots(pair_id);
CREATE INDEX IF NOT EXISTS idx_price_snapshots_time     ON price_snapshots(timestamp DESC);

CREATE TABLE IF NOT EXISTS candles (
    candle_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pair_id    TEXT NOT NULL REFERENCES trading_pairs(pair_id),
    interval   TEXT NOT NULL CHECK (interval IN ('1m', '5m', '1h', '1d')),
    open       NUMERIC(36, 18) NOT NULL,
    high       NUMERIC(36, 18) NOT NULL,
    low        NUMERIC(36, 18) NOT NULL,
    close      NUMERIC(36, 18) NOT NULL,
    volume     NUMERIC(36, 18) NOT NULL,
    open_time  TIMESTAMPTZ NOT NULL,
    close_time TIMESTAMPTZ NOT NULL,
    UNIQUE (pair_id, interval, open_time)
);
CREATE INDEX IF NOT EXISTS idx_candles_pair_interval ON candles(pair_id, interval, open_time DESC);

-- 5. Orders & Trades
CREATE TABLE IF NOT EXISTS orders (
    order_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(user_id),
    pair_id          TEXT NOT NULL REFERENCES trading_pairs(pair_id),
    side             TEXT NOT NULL CHECK (side IN ('buy', 'sell')),
    type             TEXT NOT NULL CHECK (type IN ('market', 'limit')),
    status           TEXT NOT NULL DEFAULT 'pending'
                         CHECK (status IN ('pending', 'open', 'partially_filled', 'filled', 'cancelled')),
    price            NUMERIC(36, 18),
    quantity         NUMERIC(36, 18) NOT NULL,
    filled_quantity  NUMERIC(36, 18) NOT NULL DEFAULT 0,
    locked_amount    NUMERIC(36, 18) NOT NULL DEFAULT 0,
    fee              NUMERIC(36, 18) NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_pair_id ON orders(pair_id);
CREATE INDEX IF NOT EXISTS idx_orders_status  ON orders(status);

CREATE TABLE IF NOT EXISTS trades (
    trade_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pair_id        TEXT NOT NULL REFERENCES trading_pairs(pair_id),
    maker_order_id UUID NOT NULL REFERENCES orders(order_id),
    taker_order_id UUID NOT NULL REFERENCES orders(order_id),
    price          NUMERIC(36, 18) NOT NULL,
    quantity       NUMERIC(36, 18) NOT NULL,
    maker_fee      NUMERIC(36, 18) NOT NULL DEFAULT 0,
    taker_fee      NUMERIC(36, 18) NOT NULL DEFAULT 0,
    executed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_trades_pair_id ON trades(pair_id);
CREATE INDEX IF NOT EXISTS idx_trades_executed_at ON trades(executed_at DESC);

-- 6. Crypto Addresses
CREATE TABLE IF NOT EXISTS crypto_addresses (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    currency         TEXT NOT NULL,
    chain            TEXT NOT NULL,
    address          TEXT NOT NULL,
    xpub             TEXT NOT NULL DEFAULT '',
    derivation_index INTEGER NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, currency)
);
CREATE INDEX IF NOT EXISTS idx_crypto_addresses_address ON crypto_addresses(address);
CREATE INDEX IF NOT EXISTS idx_crypto_addresses_chain   ON crypto_addresses(chain);

-- 7. Seed Data
INSERT INTO coins (coin_id, symbol, name, decimals, network, status)
VALUES 
    ('BTC', 'BTC', 'Bitcoin', 8, 'Bitcoin', 'active'),
    ('ETH', 'ETH', 'Ethereum', 18, 'Ethereum', 'active'),
    ('BNB', 'BNB', 'BNB', 18, 'Binance Smart Chain', 'active'),
    ('SOL', 'SOL', 'Solana', 9, 'Solana', 'active'),
    ('USDT', 'USDT', 'Tether USD', 6, 'Ethereum', 'active')
ON CONFLICT (coin_id) DO NOTHING;

INSERT INTO trading_pairs (pair_id, base_coin, quote_coin, status, min_order_size, price_decimal_places)
VALUES 
    ('BTC_USDT', 'BTC', 'USDT', 'active', 0.0001, 2),
    ('ETH_USDT', 'ETH', 'USDT', 'active', 0.001, 2),
    ('BNB_USDT', 'BNB', 'USDT', 'active', 0.01, 2),
    ('SOL_USDT', 'SOL', 'USDT', 'active', 0.1, 2)
ON CONFLICT (pair_id) DO NOTHING;
-- P2P marketplace: advertisements, orders, disputes

CREATE TABLE IF NOT EXISTS p2p_advertisements (
    advertisement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id        UUID NOT NULL REFERENCES users(user_id),
    pair_id          TEXT NOT NULL REFERENCES trading_pairs(pair_id),
    price            NUMERIC(36, 18) NOT NULL,
    min_amount       NUMERIC(36, 18) NOT NULL,
    max_amount       NUMERIC(36, 18) NOT NULL,
    payment_method   TEXT NOT NULL,
    payment_window   INTEGER NOT NULL,
    status           TEXT NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active', 'paused', 'completed')),
    seller_address   TEXT NOT NULL DEFAULT '',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_p2p_ads_seller_id ON p2p_advertisements(seller_id);
CREATE INDEX IF NOT EXISTS idx_p2p_ads_status    ON p2p_advertisements(status);

CREATE TABLE IF NOT EXISTS p2p_orders (
    p2p_order_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    advertisement_id UUID NOT NULL REFERENCES p2p_advertisements(advertisement_id),
    buyer_id         UUID NOT NULL REFERENCES users(user_id),
    seller_id        UUID NOT NULL REFERENCES users(user_id),
    amount           NUMERIC(36, 18) NOT NULL,
    total_idr        NUMERIC(20, 2) NOT NULL,
    status           TEXT NOT NULL DEFAULT 'created'
                         CHECK (status IN ('created', 'paid', 'released', 'disputed', 'cancelled')),
    payment_proof_url TEXT,
    escrow_wallet_id UUID REFERENCES wallets(wallet_id),
    buyer_address    TEXT NOT NULL DEFAULT '',
    seller_address   TEXT NOT NULL DEFAULT '',
    on_chain_id      TEXT NOT NULL DEFAULT '',
    escrow_state     TEXT NOT NULL DEFAULT 'none',
    create_tx_hash   TEXT,
    release_tx_hash  TEXT,
    refund_tx_hash   TEXT,
    dispute_tx_hash  TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at          TIMESTAMPTZ,
    released_at      TIMESTAMPTZ,
    expired_at       TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_p2p_orders_buyer_id  ON p2p_orders(buyer_id);
CREATE INDEX IF NOT EXISTS idx_p2p_orders_seller_id ON p2p_orders(seller_id);
CREATE INDEX IF NOT EXISTS idx_p2p_orders_on_chain_id ON p2p_orders(on_chain_id);

CREATE TABLE IF NOT EXISTS p2p_disputes (
    p2p_dispute_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    p2p_order_id   UUID NOT NULL REFERENCES p2p_orders(p2p_order_id),
    raised_by      UUID NOT NULL REFERENCES users(user_id),
    reason         TEXT NOT NULL,
    evidence_url   TEXT,
    status         TEXT NOT NULL DEFAULT 'open'
                       CHECK (status IN ('open', 'resolved')),
    resolved_by    UUID REFERENCES users(user_id),
    resolution     TEXT NOT NULL DEFAULT '',
    resolved_at    TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_p2p_disputes_order_id ON p2p_disputes(p2p_order_id);
INSERT INTO coins (coin_id, symbol, name, decimals, network, status)
VALUES 
    ('USDC', 'USDC', 'USD Coin', 6, 'Ethereum', 'active'),
    ('IDR', 'IDR', 'Indonesian Rupiah', 0, 'Fiat', 'active')
ON CONFLICT (coin_id) DO NOTHING;

INSERT INTO trading_pairs (pair_id, base_coin, quote_coin, status, min_order_size, price_decimal_places)
VALUES 
    ('USDT_IDR', 'USDT', 'IDR', 'active', 10.0, 0),
    ('USDC_IDR', 'USDC', 'IDR', 'active', 10.0, 0),
    ('BTC_IDR', 'BTC', 'IDR', 'active', 0.0001, 0),
    ('ETH_IDR', 'ETH', 'IDR', 'active', 0.001, 0)
ON CONFLICT (pair_id) DO NOTHING;
