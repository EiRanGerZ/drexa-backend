-- 000011_seed_market.up.sql
-- Seed master-data coins and USDC trading pairs so the order engine and the
-- order-book endpoint have real pairs to work with. Idempotent: safe to re-run.
--
-- coin_id is the symbol itself here for simplicity; pair_id is "<BASE>_USDC".
-- price_decimal_places mirrors how the frontend quotes each coin (more dp for
-- sub-$10 assets) and drives the matching engine's tick conversion.

INSERT INTO coins (coin_id, symbol, name, decimals, network, status) VALUES
    ('USDC', 'USDC', 'USD Coin',  6,  'ERC20',  'active'),
    ('BTC',  'BTC',  'Bitcoin',   8,  'native', 'active'),
    ('ETH',  'ETH',  'Ethereum',  18, 'native', 'active'),
    ('SOL',  'SOL',  'Solana',    9,  'native', 'active'),
    ('BNB',  'BNB',  'BNB',       18, 'native', 'active'),
    ('XRP',  'XRP',  'XRP',       6,  'native', 'active'),
    ('ADA',  'ADA',  'Cardano',   6,  'native', 'active'),
    ('AVAX', 'AVAX', 'Avalanche', 18, 'native', 'active'),
    ('LINK', 'LINK', 'Chainlink', 18, 'ERC20',  'active'),
    ('DOGE', 'DOGE', 'Dogecoin',  8,  'native', 'active'),
    ('DOT',  'DOT',  'Polkadot',  10, 'native', 'active'),
    ('MATIC','MATIC','Polygon',   18, 'native', 'active'),
    ('LTC',  'LTC',  'Litecoin',  8,  'native', 'active'),
    ('UNI',  'UNI',  'Uniswap',   18, 'ERC20',  'active'),
    ('ATOM', 'ATOM', 'Cosmos',    6,  'native', 'active'),
    ('XLM',  'XLM',  'Stellar',   7,  'native', 'active'),
    ('NEAR', 'NEAR', 'NEAR',      24, 'native', 'active'),
    ('APT',  'APT',  'Aptos',     8,  'native', 'active')
ON CONFLICT (coin_id) DO NOTHING;

INSERT INTO trading_pairs (pair_id, base_coin, quote_coin, status, min_order_size, price_decimal_places) VALUES
    ('BTC_USDC',   'BTC',   'USDC', 'active', 0.00001, 2),
    ('ETH_USDC',   'ETH',   'USDC', 'active', 0.0001,  2),
    ('SOL_USDC',   'SOL',   'USDC', 'active', 0.001,   2),
    ('BNB_USDC',   'BNB',   'USDC', 'active', 0.001,   2),
    ('XRP_USDC',   'XRP',   'USDC', 'active', 1,       6),
    ('ADA_USDC',   'ADA',   'USDC', 'active', 1,       6),
    ('AVAX_USDC',  'AVAX',  'USDC', 'active', 0.01,    2),
    ('LINK_USDC',  'LINK',  'USDC', 'active', 0.01,    2),
    ('DOGE_USDC',  'DOGE',  'USDC', 'active', 1,       6),
    ('DOT_USDC',   'DOT',   'USDC', 'active', 0.01,    4),
    ('MATIC_USDC', 'MATIC', 'USDC', 'active', 1,       6),
    ('LTC_USDC',   'LTC',   'USDC', 'active', 0.001,   2),
    ('UNI_USDC',   'UNI',   'USDC', 'active', 0.01,    4),
    ('ATOM_USDC',  'ATOM',  'USDC', 'active', 0.01,    4),
    ('XLM_USDC',   'XLM',   'USDC', 'active', 1,       6),
    ('NEAR_USDC',  'NEAR',  'USDC', 'active', 0.01,    4),
    ('APT_USDC',   'APT',   'USDC', 'active', 0.01,    4)
ON CONFLICT (pair_id) DO NOTHING;
