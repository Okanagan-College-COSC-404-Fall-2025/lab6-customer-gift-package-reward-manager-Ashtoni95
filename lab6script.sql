
CREATE OR REPLACE TYPE gift_items_list_t AS TABLE OF VARCHAR2(100);
/

CREATE TABLE gift_catalog (
    gift_id       NUMBER PRIMARY KEY,
    min_purchase  NUMBER,
    gifts         gift_items_list_t
) NESTED TABLE gifts STORE AS gift_items_store;


INSERT INTO gift_catalog VALUES (
    1, 100, gift_items_list_t('Erasers', 'Pencils')
);

INSERT INTO gift_catalog VALUES (
    2, 1000, gift_items_list_t('Plushies', 'Marbles', 'Playing Cards')
);

INSERT INTO gift_catalog VALUES (
    3, 10000, gift_items_list_t('FannyPack', 'Stanley', 'Purdys')
);

COMMIT;

CREATE TABLE customer_rewards (
    reward_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_email VARCHAR2(200),
    gift_id        NUMBER REFERENCES gift_catalog(gift_id),
    reward_date    DATE DEFAULT SYSDATE
);

CREATE OR REPLACE PACKAGE customer_manager AS
    FUNCTION get_total_purchase(p_customer_id NUMBER) RETURN NUMBER;
    PROCEDURE assign_gifts_to_all;
END customer_manager;
/


CREATE OR REPLACE PACKAGE BODY customer_manager AS

    FUNCTION choose_gift_package(p_total NUMBER) RETURN NUMBER IS
        v_gift_id gift_catalog.gift_id%TYPE;
    BEGIN
        SELECT gift_id
        INTO v_gift_id
        FROM (
            SELECT gift_id
            FROM gift_catalog
            WHERE min_purchase <= p_total
            ORDER BY min_purchase DESC
        )
        WHERE ROWNUM = 1;

        RETURN v_gift_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END choose_gift_package;

    FUNCTION get_total_purchase(p_customer_id NUMBER) RETURN NUMBER IS
        v_total NUMBER := 0;
    BEGIN
        SELECT NVL(SUM(oi.unit_price * oi.quantity), 0)
        INTO v_total
        FROM co.orders o
        JOIN co.order_items oi
            ON o.order_id = oi.order_id
        WHERE o.customer_id = p_customer_id
          AND o.order_status = 'COMPLETE';

        RETURN v_total;
    END get_total_purchase;

    PROCEDURE assign_gifts_to_all IS
    BEGIN
        FOR r IN (
            SELECT customer_id, email_address
            FROM co.customers
        ) LOOP

            DECLARE
                v_total NUMBER;
                v_giftid NUMBER;
            BEGIN
                v_total  := get_total_purchase(r.customer_id);
                v_giftid := choose_gift_package(v_total);

                IF v_giftid IS NOT NULL THEN
                    INSERT INTO customer_rewards (customer_email, gift_id)
                    VALUES (r.email_address, v_giftid);
                END IF;
            END;

        END LOOP;
    END assign_gifts_to_all;

END customer_manager;
/


CREATE OR REPLACE PROCEDURE test_rewards IS
BEGIN
    FOR r IN (
        SELECT cr.customer_email,
               cr.gift_id,
               gc.min_purchase
        FROM customer_rewards cr
        JOIN gift_catalog gc
            ON cr.gift_id = gc.gift_id
        WHERE ROWNUM <= 50
    ) LOOP

        DBMS_OUTPUT.PUT_LINE(
            'Email: ' || r.customer_email ||
            ' | Gift ID: ' || r.gift_id ||
            ' | Min Purchase: ' || r.min_purchase
        );

    END LOOP;
END;
/
BEGIN
    customer_manager.assign_gifts_to_all;
    test_rewards;
END;
/
