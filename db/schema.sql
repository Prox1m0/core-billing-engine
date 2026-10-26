CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_number VARCHAR(20) UNIQUE NOT NULL,
    owner_id UUID NOT NULL,
    currency VARCHAR(3) NOT NULL,
    type VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key UUID UNIQUE NOT NULL,
    sender_account_id UUID REFERENCES accounts(id),
    receiver_account_id UUID REFERENCES accounts(id),
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE postings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID REFERENCES transactions(id) NOT NULL,
    account_id UUID REFERENCES accounts(id) NOT NULL,
    amount INT NOT NULL CHECK (amount > 0), -- защита от отрицательных сумм
    direction VARCHAR(10) NOT NULL CHECK (direction IN ('debit', 'credit'))
);

--триггер для проверки баланса транзакции 
CREATE OR REPLACE FUNCTION check_transaction_balance() RETURNS TRIGGER AS $$
DECLARE
    total_debit INT;
    total_credit INT;
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO total_debit FROM postings WHERE transaction_id = NEW.transaction_id AND direction = 'debit';
    SELECT COALESCE(SUM(amount), 0) INTO total_credit FROM postings WHERE transaction_id = NEW.transaction_id AND direction = 'credit';
    
    IF total_debit != total_credit THEN
        RAISE EXCEPTION 'Transaction balance mismatch! Debit: %, Credit: %', total_debit, total_credit;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER ensure_balance
AFTER INSERT ON postings
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_transaction_balance();