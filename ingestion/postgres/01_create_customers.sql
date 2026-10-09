CREATE TABLE IF NOT EXISTS customers ( -- Create the table if it does not already exist.
    customer_id TEXT PRIMARY KEY, -- A unique, non-empty identifier for each customer.
    first_name TEXT NOT NULL, -- Every customer must have a first name.
    last_name TEXT NOT NULL, -- Every customer must have a last name.
    email TEXT NOT NULL, -- Every customer must have an email value.
    phone TEXT, -- Phone is optional in the data dictionary.
    city TEXT, -- City is also optional.
    loyalty_tier TEXT NOT NULL, -- Store the customer's loyalty level.
    join_date DATE NOT NULL, -- Store a calendar date, rather than plain text.
    active_flag BOOLEAN NOT NULL, -- Store true or false.
    CONSTRAINT customers_email_contains_at CHECK (email LIKE '%@%'), -- Apply the dictionary's basic email rule.
    CONSTRAINT customers_loyalty_tier_valid CHECK (loyalty_tier IN ('Bronze', 'Silver', 'Gold')) -- Allow only the listed tiers.
); -- End the table definition.
