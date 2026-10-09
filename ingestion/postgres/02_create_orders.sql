CREATE TABLE IF NOT EXISTS orders ( -- Create the orders table once.
    order_id TEXT PRIMARY KEY, -- Identify each order uniquely.
    customer_id TEXT NOT NULL, -- Identify the customer who placed it.
    store_id TEXT NOT NULL, -- Identify the store; stores remain a CSV source for now.
    order_ts TIMESTAMP NOT NULL, -- Store when the order was placed.
    updated_at TIMESTAMP NOT NULL, -- Store when it was last updated.
    status TEXT NOT NULL, -- Store completed, cancelled, or returned.
    channel TEXT NOT NULL, -- Store store or online.
    promo_id TEXT, -- An order may have no promotion.
    subtotal NUMERIC(12, 2) NOT NULL, -- Store an exact amount with two decimal places.
    discount_amount NUMERIC(12, 2) NOT NULL, -- Store the discount amount.
    tax_amount NUMERIC(12, 2) NOT NULL, -- Store the tax amount.
    total_amount NUMERIC(12, 2) NOT NULL, -- Store the final order amount.
    currency_code TEXT NOT NULL, -- Store the currency code.
    CONSTRAINT orders_customer_fk FOREIGN KEY (customer_id) REFERENCES customers(customer_id), -- Require an existing customer.
    CONSTRAINT orders_updated_at_valid CHECK (updated_at >= order_ts), -- Updates cannot precede the order.
    CONSTRAINT orders_status_valid CHECK (status IN ('completed', 'cancelled', 'returned')), -- Allow known statuses.
    CONSTRAINT orders_channel_valid CHECK (channel IN ('store', 'online')), -- Allow known channels.
    CONSTRAINT orders_amounts_nonnegative CHECK (subtotal >= 0 AND discount_amount >= 0 AND tax_amount >= 0 AND total_amount >= 0), -- Reject negative amounts.
    CONSTRAINT orders_currency_pkr CHECK (currency_code = 'PKR') -- This dataset uses PKR.
); -- End the table definition.