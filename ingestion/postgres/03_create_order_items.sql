CREATE TABLE IF NOT EXISTS order_items ( -- Create the table for individual order lines.
    order_item_id TEXT PRIMARY KEY, -- Identify each line uniquely.
    order_id TEXT NOT NULL, -- Identify the order containing this line.
    product_id TEXT NOT NULL, -- Identify the product; products remain a CSV source.
    quantity INTEGER NOT NULL CHECK (quantity > 0), -- Require at least one unit.
    unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0), -- Store a non-negative unit price.
    line_total NUMERIC(12, 2) NOT NULL, -- Store the supplied line amount.
    currency_code TEXT NOT NULL CHECK (currency_code = 'PKR'), -- Require this dataset's currency.
    CONSTRAINT order_items_order_fk FOREIGN KEY (order_id) REFERENCES orders(order_id) -- Require an existing order.
); -- End the table definition.