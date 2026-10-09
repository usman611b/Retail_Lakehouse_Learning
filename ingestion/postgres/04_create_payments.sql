CREATE TABLE IF NOT EXISTS payments ( -- Create the payments table.
    payment_id TEXT PRIMARY KEY, -- Identify each payment uniquely.
    order_id TEXT NOT NULL, -- Identify the order being paid for.
    payment_ts TIMESTAMP NOT NULL, -- Store when the payment happened.
    payment_method TEXT NOT NULL, -- Store cash, card, wallet, or bank transfer.
    payment_status TEXT NOT NULL, -- Store paid, refunded, or cancelled.
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0), -- Store a non-negative payment amount.
    currency_code TEXT NOT NULL CHECK (currency_code = 'PKR'), -- Require this dataset's currency.
    CONSTRAINT payments_order_fk FOREIGN KEY (order_id) REFERENCES orders(order_id), -- Require an existing order.
    CONSTRAINT payments_method_valid CHECK (payment_method IN ('cash', 'card', 'wallet', 'bank_transfer')), -- Allow known methods.
    CONSTRAINT payments_status_valid CHECK (payment_status IN ('paid', 'refunded', 'cancelled')) -- Allow known statuses.
); -- End the table definition.