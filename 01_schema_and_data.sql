-- ============================================================
-- PROJECT  : SQL-Based Data Analysis — Retail Sales Domain
-- DATABASE : PostgreSQL 14+
-- FILE     : 01_schema_and_data.sql
-- PURPOSE  : Create schema, indexes, and populate ~50,000+ rows
--            of realistic retail/sales data across three
--            business domains: Customers, Products, Orders.
-- AUTHOR   : Data Analyst Portfolio Project
-- ============================================================

-- ============================================================
-- SECTION 0 — DATABASE SETUP
-- ============================================================
-- Run in an existing PostgreSQL database, e.g.:
--   CREATE DATABASE retail_analytics;
--   \c retail_analytics

-- ============================================================
-- SECTION 1 — DROP EXISTING OBJECTS (safe re-run)
-- ============================================================
DROP TABLE IF EXISTS order_items  CASCADE;
DROP TABLE IF EXISTS orders       CASCADE;
DROP TABLE IF EXISTS products     CASCADE;
DROP TABLE IF EXISTS categories   CASCADE;
DROP TABLE IF EXISTS customers    CASCADE;
DROP TABLE IF EXISTS regions      CASCADE;

-- ============================================================
-- SECTION 2 — DIMENSION TABLES
-- ============================================================

-- ---------------------------------------------------------------
-- TABLE: regions
-- Business purpose: Stores geographic sales regions used to
-- segment revenue, assign sales reps, and drive regional KPIs.
-- ---------------------------------------------------------------
CREATE TABLE regions (
    region_id   SERIAL        PRIMARY KEY,
    region_name VARCHAR(50)   NOT NULL UNIQUE,
    country     VARCHAR(50)   NOT NULL DEFAULT 'United States'
);

INSERT INTO regions (region_name, country) VALUES
    ('North East',  'United States'),
    ('South East',  'United States'),
    ('Mid West',    'United States'),
    ('South West',  'United States'),
    ('West Coast',  'United States'),
    ('Northwest',   'United States');

-- ---------------------------------------------------------------
-- TABLE: categories
-- Business purpose: Product taxonomy used for merchandising,
-- promotions, and category-level P&L reporting. Supports a
-- parent→child hierarchy (up to 2 levels) for recursive queries.
-- ---------------------------------------------------------------
CREATE TABLE categories (
    category_id   SERIAL       PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    parent_id     INT          REFERENCES categories(category_id),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE
);

-- Top-level categories (parent_id NULL)
INSERT INTO categories (category_name, parent_id, is_active) VALUES
    ('Electronics',          NULL, TRUE),   -- 1
    ('Clothing & Apparel',   NULL, TRUE),   -- 2
    ('Home & Garden',        NULL, TRUE),   -- 3
    ('Sports & Outdoors',    NULL, TRUE),   -- 4
    ('Books & Media',        NULL, FALSE),  -- 5  (inactive)
    ('Food & Beverage',      NULL, TRUE);   -- 6

-- Sub-categories
INSERT INTO categories (category_name, parent_id, is_active) VALUES
    ('Smartphones',      1, TRUE),   -- 7
    ('Laptops',          1, TRUE),   -- 8
    ('Audio',            1, TRUE),   -- 9
    ('Wearables',        1, TRUE),   -- 10
    ('Men''s Clothing',  2, TRUE),   -- 11
    ('Women''s Clothing',2, TRUE),   -- 12
    ('Footwear',         2, TRUE),   -- 13
    ('Furniture',        3, TRUE),   -- 14
    ('Kitchen',          3, TRUE),   -- 15
    ('Garden Tools',     3, TRUE),   -- 16
    ('Fitness',          4, TRUE),   -- 17
    ('Camping',          4, TRUE),   -- 18
    ('Nutrition',        6, TRUE),   -- 19
    ('Beverages',        6, TRUE);   -- 20

-- ---------------------------------------------------------------
-- TABLE: customers
-- Business purpose: Core CRM entity. Stores demographic and
-- segmentation data used for targeted marketing campaigns and
-- customer lifetime value analysis.
-- ---------------------------------------------------------------
CREATE TABLE customers (
    customer_id     SERIAL        PRIMARY KEY,
    first_name      VARCHAR(50)   NOT NULL,
    last_name       VARCHAR(50)   NOT NULL,
    email           VARCHAR(120)  NOT NULL UNIQUE,
    phone           VARCHAR(20),
    region_id       INT           NOT NULL REFERENCES regions(region_id),
    segment         VARCHAR(20)   NOT NULL CHECK (segment IN ('Bronze','Silver','Gold','Platinum')),
    date_joined     DATE          NOT NULL,
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_customers_region   ON customers(region_id);
CREATE INDEX idx_customers_segment  ON customers(segment);
CREATE INDEX idx_customers_joined   ON customers(date_joined);

-- ---------------------------------------------------------------
-- TABLE: products
-- Business purpose: Product catalogue with cost and pricing.
-- Used for margin analysis, inventory planning, and promotional
-- eligibility checks.
-- ---------------------------------------------------------------
CREATE TABLE products (
    product_id      SERIAL          PRIMARY KEY,
    product_name    VARCHAR(150)    NOT NULL,
    category_id     INT             NOT NULL REFERENCES categories(category_id),
    unit_cost       NUMERIC(10,2)   NOT NULL,
    unit_price      NUMERIC(10,2)   NOT NULL,
    stock_qty       INT             NOT NULL DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_products_category  ON products(category_id);
CREATE INDEX idx_products_active    ON products(is_active);

-- ---------------------------------------------------------------
-- TABLE: orders
-- Business purpose: Transactional order header. Each row
-- represents one customer checkout event. Used for revenue,
-- order-frequency, and cohort analyses.
-- ---------------------------------------------------------------
CREATE TABLE orders (
    order_id        SERIAL          PRIMARY KEY,
    customer_id     INT             NOT NULL REFERENCES customers(customer_id),
    order_date      DATE            NOT NULL,
    shipped_date    DATE,
    status          VARCHAR(20)     NOT NULL CHECK (status IN ('Pending','Processing','Shipped','Delivered','Cancelled','Returned')),
    payment_method  VARCHAR(30)     NOT NULL,
    discount_pct    NUMERIC(5,2)    NOT NULL DEFAULT 0.00
);

CREATE INDEX idx_orders_customer    ON orders(customer_id);
CREATE INDEX idx_orders_date        ON orders(order_date);
CREATE INDEX idx_orders_status      ON orders(status);

-- ---------------------------------------------------------------
-- TABLE: order_items
-- Business purpose: Order line items. Joins orders↔products and
-- captures quantity + actual unit price at time of purchase
-- (may differ from current catalogue price).
-- ---------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id   SERIAL          PRIMARY KEY,
    order_id        INT             NOT NULL REFERENCES orders(order_id),
    product_id      INT             NOT NULL REFERENCES products(product_id),
    quantity        INT             NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(10,2)   NOT NULL,
    discount_pct    NUMERIC(5,2)    NOT NULL DEFAULT 0.00
);

CREATE INDEX idx_order_items_order    ON order_items(order_id);
CREATE INDEX idx_order_items_product  ON order_items(product_id);

-- ============================================================
-- SECTION 3 — PRODUCTS SEED DATA  (80 products)
-- ============================================================
INSERT INTO products (product_name, category_id, unit_cost, unit_price, stock_qty, is_active) VALUES
-- Smartphones (cat 7)
('Samsung Galaxy S24 Ultra',   7,  820.00, 1199.99, 450, TRUE),
('Apple iPhone 15 Pro',        7,  780.00, 1099.99, 320, TRUE),
('Google Pixel 8 Pro',         7,  580.00,  899.99, 280, TRUE),
('OnePlus 12',                 7,  420.00,  649.99, 210, TRUE),
('Motorola Edge 40 Pro',       7,  310.00,  499.99, 180, TRUE),
-- Laptops (cat 8)
('Dell XPS 15 Laptop',         8,  950.00, 1499.99, 200, TRUE),
('Apple MacBook Pro 14"',      8, 1200.00, 1999.99, 150, TRUE),
('Lenovo ThinkPad X1 Carbon',  8,  880.00, 1349.99, 175, TRUE),
('HP Spectre x360',            8,  750.00, 1149.99, 220, TRUE),
('ASUS ROG Gaming Laptop',     8,  870.00, 1299.99, 130, TRUE),
-- Audio (cat 9)
('Sony WH-1000XM5 Headphones', 9,  180.00,  349.99, 600, TRUE),
('Apple AirPods Pro 2nd Gen',  9,  140.00,  249.99, 850, TRUE),
('Bose QuietComfort 45',       9,  160.00,  299.99, 420, TRUE),
('JBL Charge 5 Speaker',       9,   80.00,  149.99, 380, TRUE),
('Sonos Era 100',              9,  150.00,  249.99, 200, TRUE),
-- Wearables (cat 10)
('Apple Watch Series 9',      10,  270.00,  399.99, 520, TRUE),
('Samsung Galaxy Watch 6',    10,  180.00,  279.99, 310, TRUE),
('Fitbit Charge 6',           10,   90.00,  159.99, 480, TRUE),
('Garmin Forerunner 965',     10,  290.00,  499.99, 180, TRUE),
-- Men''s Clothing (cat 11)
('Levi''s 501 Original Jeans',11,   28.00,   69.99, 900, TRUE),
('Ralph Lauren Oxford Shirt', 11,   22.00,   54.99, 750, TRUE),
('Nike Dri-FIT T-Shirt',      11,   14.00,   34.99,1200, TRUE),
('Patagonia Fleece Jacket',   11,   55.00,  129.99, 400, TRUE),
('Adidas Track Pants',        11,   18.00,   44.99, 600, TRUE),
-- Women''s Clothing (cat 12)
('Zara Floral Midi Dress',    12,   25.00,   59.99, 700, TRUE),
('H&M Knit Sweater',          12,   15.00,   39.99, 850, TRUE),
('Anthropologie Blazer',      12,   60.00,  139.99, 250, TRUE),
('Lululemon Align Leggings',  12,   42.00,   98.00, 650, TRUE),
('J.Crew Chambray Blouse',    12,   20.00,   49.99, 500, TRUE),
-- Footwear (cat 13)
('Nike Air Max 270',          13,   60.00,  149.99, 800, TRUE),
('Adidas Ultraboost 23',      13,   80.00,  179.99, 600, TRUE),
('Timberland 6" Boot',        13,   75.00,  169.99, 350, TRUE),
('Birkenstock Arizona',       13,   45.00,  109.99, 420, TRUE),
('Converse Chuck Taylor',     13,   25.00,   59.99, 950, TRUE),
-- Furniture (cat 14)
('IKEA BEKANT Desk',          14,   95.00,  249.99, 120, TRUE),
('Herman Miller Aeron Chair', 14,  800.00, 1495.00,  60, TRUE),
('West Elm Mid-Century Sofa', 14,  650.00, 1299.99,  40, TRUE),
('Wayfair Bookshelf',         14,   55.00,  149.99, 200, TRUE),
('Pottery Barn Coffee Table', 14,  220.00,  549.99,  80, TRUE),
-- Kitchen (cat 15)
('Instant Pot Duo 7-in-1',    15,   45.00,   99.99, 500, TRUE),
('KitchenAid Stand Mixer',    15,  180.00,  449.99, 160, TRUE),
('Ninja Air Fryer',           15,   60.00,  129.99, 450, TRUE),
('Vitamix Blender',           15,  200.00,  549.99, 100, TRUE),
('Cuisinart Coffee Maker',    15,   45.00,   89.99, 350, TRUE),
-- Garden Tools (cat 16)
('Black+Decker Cordless Drill',16,  40.00,   79.99, 400, TRUE),
('Husqvarna Gas Trimmer',     16,  110.00,  249.99, 150, TRUE),
('Fiskars Pruning Shears',    16,   12.00,   24.99, 800, TRUE),
('DeWalt 20V Chainsaw',       16,  160.00,  329.99, 120, TRUE),
-- Fitness (cat 17)
('Peloton Bike+',             17, 1800.00, 2495.00,  30, TRUE),
('Bowflex SelectTech Dumbbells',17,150.00,  329.99, 200, TRUE),
('TRX Suspension Trainer',    17,   55.00,  119.99, 300, TRUE),
('Yoga Mat Premium',          17,   18.00,   44.99, 700, TRUE),
('Resistance Band Set',       17,    8.00,   24.99,1000, TRUE),
-- Camping (cat 18)
('REI Co-op Half Dome Tent',  18,  120.00,  279.99, 180, TRUE),
('Coleman Sleeping Bag',      18,   35.00,   79.99, 350, TRUE),
('Yeti Tundra 45 Cooler',     18,  175.00,  349.99, 140, TRUE),
('Hydro Flask Water Bottle',  18,   18.00,   44.99, 900, TRUE),
('Black Diamond Headlamp',    18,   20.00,   44.99, 450, TRUE),
-- Nutrition (cat 19)
('Optimum Nutrition Whey 5lb',19,   28.00,   64.99, 600, TRUE),
('Orgain Organic Protein',    19,   22.00,   49.99, 500, TRUE),
('Garden of Life Multivitamin',19,  18.00,   39.99, 700, TRUE),
('NOW Foods Vitamin D3',      19,    5.00,   14.99,1200, TRUE),
('Omega-3 Fish Oil 1000mg',   19,    8.00,   19.99,1100, TRUE),
-- Beverages (cat 20)
('Nespresso Vertuo Next',     20,   80.00,  179.99, 300, TRUE),
('Keurig K-Elite Brewer',     20,   75.00,  169.99, 250, TRUE),
('Nespresso Pods 50ct',       20,   22.00,   49.99,1500, TRUE),
('Starbucks Ground Coffee 2lb',20,  14.00,   29.99,2000, TRUE),
-- Additional high-margin electronics
('iPad Pro 12.9"',             7,  720.00, 1099.99, 200, TRUE),
('Dell 27" 4K Monitor',        8,  280.00,  549.99, 180, TRUE),
('Logitech MX Keys Keyboard',  9,   55.00,  109.99, 600, TRUE),
('Anker 65W USB-C Charger',    9,   18.00,   39.99,1800, TRUE),
('GoPro HERO12 Black',         7,  220.00,  399.99, 250, TRUE),
('Ring Video Doorbell Pro',   10,  130.00,  249.99, 300, TRUE),
('Echo Dot 5th Gen',           9,   28.00,   49.99,2000, TRUE),
('Fire TV Stick 4K Max',       9,   30.00,   59.99,1500, TRUE),
('Kindle Paperwhite',          8,   80.00,  139.99, 700, TRUE),
('Nintendo Switch OLED',       7,  250.00,  349.99, 400, TRUE);

-- ============================================================
-- SECTION 4 — CUSTOMERS  (2,000 rows via generate_series)
-- ============================================================
INSERT INTO customers (first_name, last_name, email, phone, region_id, segment, date_joined, is_active)
SELECT
    (ARRAY['James','Mary','John','Patricia','Robert','Jennifer','Michael','Linda',
           'William','Barbara','David','Susan','Richard','Jessica','Joseph','Sarah',
           'Thomas','Karen','Charles','Lisa','Christopher','Nancy','Daniel','Betty',
           'Matthew','Margaret','Anthony','Sandra','Mark','Ashley'])[((n-1) % 30)+1]
        AS first_name,
    (ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis',
           'Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson',
           'Thomas','Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson',
           'White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson'])[((n-1) % 30)+1]
        AS last_name,
    'customer' || n || '@retaildemo.com'          AS email,
    '555-' || LPAD((n % 10000)::TEXT, 4, '0')    AS phone,
    (n % 6) + 1                                   AS region_id,
    (ARRAY['Bronze','Silver','Gold','Platinum'])[ CASE
        WHEN n % 10 IN (0,1,2,3,4) THEN 1   -- 50% Bronze
        WHEN n % 10 IN (5,6,7)     THEN 2   -- 30% Silver
        WHEN n % 10 IN (8,9)       THEN 3   -- 20% Gold / Platinum split below
        ELSE 4 END ]::VARCHAR(20)             AS segment,
    DATE '2019-01-01' + (n % 1826)               AS date_joined,
    CASE WHEN n % 25 = 0 THEN FALSE ELSE TRUE END AS is_active
FROM generate_series(1, 2000) AS n;

-- Fix Platinum: reclassify every 20th customer to Platinum
UPDATE customers SET segment = 'Platinum' WHERE customer_id % 20 = 0;

-- ============================================================
-- SECTION 5 — ORDERS  (~12,000 rows)
-- ============================================================
INSERT INTO orders (customer_id, order_date, shipped_date, status, payment_method, discount_pct)
SELECT
    (n % 2000) + 1                                           AS customer_id,
    DATE '2020-01-01' + (n % 1460)                          AS order_date,
    CASE
        WHEN n % 7 = 0 THEN NULL   -- not yet shipped
        ELSE DATE '2020-01-01' + (n % 1460) + (n % 5) + 1
    END                                                      AS shipped_date,
    (ARRAY['Delivered','Delivered','Delivered','Shipped','Processing',
           'Cancelled','Returned'])[(n % 7)+1]               AS status,
    (ARRAY['Credit Card','Credit Card','PayPal','Debit Card',
           'Bank Transfer','Apple Pay','Google Pay'])[(n % 7)+1] AS payment_method,
    ROUND((CASE WHEN n % 8 = 0 THEN 10.00
                WHEN n % 8 = 1 THEN 5.00
                ELSE 0.00 END)::NUMERIC, 2)                  AS discount_pct
FROM generate_series(1, 12000) AS n;

-- ============================================================
-- SECTION 6 — ORDER ITEMS  (~38,000 rows, total ≈ 50,000)
-- ============================================================
INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_pct)
SELECT
    ord.order_id,
    ((ord.order_id * prime + line_n * 7) % 80) + 1          AS product_id,
    (((ord.order_id + line_n) % 4) + 1)                     AS quantity,
    p.unit_price * (1 - (ord.discount_pct / 100.0))         AS unit_price,
    ord.discount_pct
FROM (
    -- generate 1-4 line items per order using a lateral cross join
    SELECT o.order_id, o.discount_pct, gs.line_n,
           1009 AS prime   -- prime multiplier for pseudo-random product selection
    FROM   orders o
    CROSS JOIN generate_series(1,
               CASE WHEN o.order_id % 4 = 0 THEN 4
                    WHEN o.order_id % 4 = 1 THEN 3
                    WHEN o.order_id % 4 = 2 THEN 2
                    ELSE 1 END) AS gs(line_n)
) ord
JOIN products p ON p.product_id = ((ord.order_id * ord.prime + ord.line_n * 7) % 80) + 1;

-- ============================================================
-- SECTION 7 — VERIFY ROW COUNTS
-- ============================================================
SELECT 'regions'     AS tbl, COUNT(*) AS rows FROM regions
UNION ALL
SELECT 'categories',                COUNT(*) FROM categories
UNION ALL
SELECT 'customers',                 COUNT(*) FROM customers
UNION ALL
SELECT 'products',                  COUNT(*) FROM products
UNION ALL
SELECT 'orders',                    COUNT(*) FROM orders
UNION ALL
SELECT 'order_items',               COUNT(*) FROM order_items
UNION ALL
SELECT '--- TOTAL ---',
    (SELECT COUNT(*) FROM regions)
  + (SELECT COUNT(*) FROM categories)
  + (SELECT COUNT(*) FROM customers)
  + (SELECT COUNT(*) FROM products)
  + (SELECT COUNT(*) FROM orders)
  + (SELECT COUNT(*) FROM order_items);
