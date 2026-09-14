-- WITH source AS(SELECT * FROM {{ ref("Jcars_logistics_dataset")}})
-- SELECT
-- NULLIF(NULLIF(TRIM(UPPER(REGEXP_REPLACE(order_id, '-', ''))), ''), 'N/A') AS order_id,
-- NULLIF(NULLIF(TRIM(INITCAP(customer_name)), 'N/A'), '') AS customer_name,
-- REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(NULLIF(REGEXP_REPLACE(TRIM(INITCAP(customer_type)), 'Ngo', 'NGO'), 'N/A'), 'Corp', 'Corporate'), 'Govt', 'Government'), 'Car Dealer', 'Dealer'), 'N.G.O', 'NGO'), 'Corporateorate', 'Corporate') AS customer_type,
-- NULLIF(NULLIF(NULLIF(NULLIF(NULLIF(REGEXP_REPLACE(customer_age,'thirty', '30'), 'unknown'), '-5'), '-'), '0'), 'N/A')::NUMERIC AS customer_age, 
-- REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(INITCAP(region), 'Cost', 'Coast'), 'Cental', 'Central'), 'East', 'Eastern'), 'Eastrn', 'Eastern'), 'Ksm region', 'Nyanza'), 'Msa Region', 'Coast'), 'Nbi', 'Nairobi'), 'Nairobii', 'Nairobi'), 'Nyanza Region', 'Nyanza'), 'Rift', 'Rift Valley'), 'Riftvalley', 'Rift valley'), '-', ''), 'West', 'Western'), 'East', 'Eastern'), 'nrb', 'Nairobi'), 'ksm region', 'Nyanza'), 'Easternern', 'Eastern'), 'Easternernern', 'Eastern'), 'Easternernern', 'Eastern') AS region,
-- REGEXP_REPLACE(REGEXP_REPLACE(County, 'Kiambu County', 'Kiambu'), 'KIAMBU COUNTY', 'Kiambu') AS County

-- FROM source




WITH source AS (
    SELECT * FROM {{ ref("Jcars_logistics_dataset") }}
)

SELECT
    -- Clean order_id
    NULLIF(NULLIF(TRIM(UPPER(REGEXP_REPLACE(order_id, '-', ''))), ''), 'N/A') AS order_id,
    
    -- Clean customer_name
    NULLIF(NULLIF(TRIM(INITCAP(customer_name)), 'N/A'), '') AS customer_name,
    
    -- Clean customer_type using a CASE statement
    CASE 
        WHEN LOWER(TRIM(customer_type)) IN ('ngo', 'n.g.o') THEN 'NGO'
        WHEN LOWER(TRIM(customer_type)) IN ('corp', 'corporate', 'corporateorate') THEN 'Corporate'
        WHEN LOWER(TRIM(customer_type)) IN ('car dealer', 'dealer') THEN 'Dealer'
        WHEN LOWER(TRIM(customer_type)) IN ('govt', 'government') THEN 'Government'
        WHEN LOWER(TRIM(customer_type)) IN ('n/a', '') THEN NULL
        ELSE INITCAP(TRIM(customer_type))
    END AS customer_type,
    
    -- Clean customer_age
    NULLIF(NULLIF(NULLIF(NULLIF(NULLIF(REGEXP_REPLACE(customer_age, 'thirty', '30'), 'unknown'), '-5'), '-'), '0'), 'N/A')::NUMERIC AS customer_age,
    
    -- Clean region using a CASE statement
    CASE 
        WHEN LOWER(TRIM(region)) IN ('nrb', 'nairobii', 'nairobi county', 'nbi', 'nairobi') THEN 'Nairobi'
        WHEN LOWER(TRIM(region)) IN ('rift-valley', 'rift valley', 'rift', 'riftvalley') THEN 'Rift Valley'
        WHEN LOWER(TRIM(region)) IN ('cental', 'central') THEN 'Central'
        WHEN LOWER(TRIM(region)) IN ('nyanza region', 'ksm region', 'nyanza') THEN 'Nyanza'
        WHEN LOWER(TRIM(region)) IN ('east', 'eastrn', 'eastern', 'easternern') THEN 'Eastern'
        WHEN LOWER(TRIM(region)) IN ('cost', 'msa region', 'coast') THEN 'Coast'
        WHEN LOWER(TRIM(region)) IN ('west', 'western', 'westernern') THEN 'Western'
        ELSE INITCAP(TRIM(region))::VARCHAR
    END AS region,
       /* ================================
       CLEAN ORDER DATE
       ================================ */
    CASE
        -- NULL / invalid values
        WHEN ORDER_DATE IS NULL
            OR LOWER(TRIM(TO_VARCHAR(ORDER_DATE))) IN
               ('null', 'not sure', '#date!', '', 'none')
            THEN NULL

        -- Fix incorrectly interpreted years:
        -- 0025-06-29 -> 2025-06-29
        -- 0026-01-15 -> 2026-01-15
        WHEN REGEXP_LIKE(TRIM(TO_VARCHAR(ORDER_DATE)), '^00(25|26)-')
            THEN TRY_TO_DATE(
                '20' || SUBSTR(TRIM(TO_VARCHAR(ORDER_DATE)), 3),
                'YYYY-MM-DD'
            )

        -- Fix month/day inversion:
        -- 2026-13-04 -> 2026-04-13
        WHEN REGEXP_LIKE(
            TRIM(TO_VARCHAR(ORDER_DATE)),
            '^[0-9]{4}-13-[0-9]{2}$'
        )
            THEN TRY_TO_DATE(
                SUBSTR(TRIM(TO_VARCHAR(ORDER_DATE)), 1, 4)
                || '-'
                || SUBSTR(TRIM(TO_VARCHAR(ORDER_DATE)), 9, 2)
                || '-13',
                'YYYY-MM-DD'
            )

        -- Excel serial date (positive integers only)
        WHEN REGEXP_LIKE(TRIM(TO_VARCHAR(ORDER_DATE)), '^[0-9]{1,6}$')
            THEN DATEADD(
                DAY,
                TRY_TO_NUMBER(TRIM(TO_VARCHAR(ORDER_DATE)))::INTEGER,
                DATE '1899-12-30'
            )

        -- M/D/YYYY or M/D/YY  (e.g. 1/2/25, 6/19/2026)
        WHEN REGEXP_LIKE(TRIM(TO_VARCHAR(ORDER_DATE)), '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4}$')
            THEN COALESCE(
                TRY_TO_DATE(TRIM(TO_VARCHAR(ORDER_DATE)), 'MM/DD/YYYY'),
                TRY_TO_DATE(TRIM(TO_VARCHAR(ORDER_DATE)), 'MM/DD/YY')
            )

        -- Normal / fallback date parsing
        ELSE COALESCE(
            TRY_TO_DATE(TRIM(TO_VARCHAR(ORDER_DATE)), 'YYYY-MM-DD'),
            TRY_TO_DATE(TRIM(TO_VARCHAR(ORDER_DATE)))
        )
    END AS cleaned_order_date,

    /* ================================
       CLEAN DELIVERY DATE
       ================================ */
    CASE
        WHEN DELIVERY_DATE IS NULL
            OR LOWER(TRIM(TO_VARCHAR(DELIVERY_DATE))) IN
               ('null', 'not sure', '#date!', '', 'none')
            THEN NULL

        WHEN REGEXP_LIKE(TRIM(TO_VARCHAR(DELIVERY_DATE)), '^00(25|26)-')
            THEN TRY_TO_DATE(
                '20' || SUBSTR(TRIM(TO_VARCHAR(DELIVERY_DATE)), 3),
                'YYYY-MM-DD'
            )

        WHEN REGEXP_LIKE(
            TRIM(TO_VARCHAR(DELIVERY_DATE)),
            '^[0-9]{4}-13-[0-9]{2}$'
        )
            THEN TRY_TO_DATE(
                SUBSTR(TRIM(TO_VARCHAR(DELIVERY_DATE)), 1, 4)
                || '-'
                || SUBSTR(TRIM(TO_VARCHAR(DELIVERY_DATE)), 9, 2)
                || '-13',
                'YYYY-MM-DD'
            )

        WHEN REGEXP_LIKE(TRIM(TO_VARCHAR(DELIVERY_DATE)), '^[0-9]{1,6}$')
            THEN DATEADD(
                DAY,
                TRY_TO_NUMBER(TRIM(TO_VARCHAR(DELIVERY_DATE)))::INTEGER,
                DATE '1899-12-30'
            )

        -- M/D/YYYY or M/D/YY  (e.g. 1/4/25, 7/1/2026)
        WHEN REGEXP_LIKE(TRIM(TO_VARCHAR(DELIVERY_DATE)), '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4}$')
            THEN COALESCE(
                TRY_TO_DATE(TRIM(TO_VARCHAR(DELIVERY_DATE)), 'MM/DD/YYYY'),
                TRY_TO_DATE(TRIM(TO_VARCHAR(DELIVERY_DATE)), 'MM/DD/YY')
            )

        ELSE COALESCE(
            TRY_TO_DATE(TRIM(TO_VARCHAR(DELIVERY_DATE)), 'YYYY-MM-DD'),
            TRY_TO_DATE(TRIM(TO_VARCHAR(DELIVERY_DATE)))
        )
    END AS cleaned_delivery_date,

   CASE

        -- Eldoret
        WHEN LOWER(TRIM(county)) LIKE '%eldoret%'
            THEN 'Eldoret'


        -- Kakamega
        WHEN LOWER(TRIM(county)) LIKE '%kakamega%'
            THEN 'Kakamega'


        -- Kiambu
        WHEN LOWER(TRIM(county)) LIKE '%kiambu%'
            THEN 'Kiambu'


        -- Kisumu
        WHEN LOWER(TRIM(county)) IN (
            'kisumu',
            'kisumu county',
            'ksm'
        )
            THEN 'Kisumu'


        -- Machakos
        WHEN LOWER(TRIM(county)) IN (
            'machakos',
            'mks'
        )
            THEN 'Machakos'


        -- Mombasa
        WHEN LOWER(TRIM(county)) IN (
            'mombasa',
            'mombasa county',
            'msa'
        )
            THEN 'Mombasa'


        -- Nakuru
        WHEN LOWER(TRIM(county)) IN (
            'nakuru',
            'nakuru county',
            'nkr'
        )
            THEN 'Nakuru'


        -- Nairobi
        WHEN LOWER(TRIM(county)) IN (
            'nairobi',
            'nairobi county',
            'nrb',
            'nairobii'
        )
            THEN 'Nairobi'


        -- Uasin Gishu
        WHEN LOWER(TRIM(county)) IN (
            'uasin gishu',
            'uasin-gishu',
            'uasingishu',
            'uasingishu county'
        )
            THEN 'Uasin Gishu'


        -- Missing / invalid county
        WHEN LOWER(TRIM(county)) IN (
            'county',
            '',
            'n/a',
            'unknown'
        )
            THEN NULL


        -- Keep any other county values
        ELSE INITCAP(TRIM(county))::VARCHAR

    END AS county, 

CASE
    -- For Athi River 
    WHEN LOWER(TRIM(city)) LIKE '%athi' THEN 'Athi River'
    WHEN LOWER(TRIM(city)) LIKE 'athiriver' THEN 'Athi River'
    -- For Eldoret
    WHEN LOWER(TRIM(city)) LIKE '%eld' THEN 'Eldoret'
    -- For Kakamega
    WHEN LOWER(TRIM(city)) LIKE '%kakamega' THEN 'Kakamega'
    WHEN LOWER(TRIM(city)) LIKE 'kakamega town' THEN 'kakamega'
    -- For Kisumu
    WHEN LOWER(TRIM(city)) LIKE '%ksm' THEN 'Kisumu'
    -- For Mombasa
    WHEN LOWER(TRIM(city)) LIKE '%msa' THEN 'Mombasa' 
    WHEN LOWER(TRIM(city)) LIKE '%nyali' THEN 'Mombasa'
    -- For Nakuru
    WHEN LOWER(TRIM(city)) LIKE 'nkr' THEN 'Nakuru'
    -- For Niarobi
    WHEN LOWER(TRIM(city)) LIKE '%westlands' THEN 'Nairobi'
    WHEN LOWER(TRIM(city)) LIKE '%emba' THEN 'Nairobi'
    WHEN LOWER(TRIM(city)) LIKE 'mlolongo' THEN 'Nairobi'
    WHEN LOWER(TRIM(city)) LIKE '%thikka' THEN 'Thika'
    WHEN LOWER(TRIM(city)) LIKE 'embakasi' THEN 'Nairobu'
    ELSE
        INITCAP(TRIM(city))::VARCHAR
END AS city, 
CASE
-- For Athi River Yard
    WHEN LOWER(TRIM(Branch)) LIKE 'athi river' THEN 'Athi River Yard'
    WHEN LOWER(TRIM(Branch)) LIKE 'athiriver yard' THEN 'Athi River Yard'
-- For Eldoret Yard
    WHEN LOWER(TRIM(Branch)) LIKE '%eld yard' THEN  'Eldoret Yard'
    WHEN LOWER(TRIM(Branch)) LIKE 'eldoret' THEN 'Eldoret Yard'
      WHEN LOWER(TRIM(Branch)) LIKE 'eldoret branch' THEN 'Eldoret Yard'
-- For Kakamega Yard
    WHEN LOWER(TRIM(Branch)) LIKE '%kakamega' THEN 'Kakamega Yard'
      WHEN LOWER(TRIM(Branch)) LIKE 'kakamega branch' THEN 'Kakamega Yard'
-- For Kisumu
    WHEN LOWER(TRIM(Branch)) LIKE 'kisumu branch' THEN 'Kisumu Yard'
    WHEN LOWER(TRIM(Branch)) LIKE 'ksm yard' THEN 'Kisumu Yard'
-- For Mambasa
    WHEN LOWER(TRIM(Branch)) LIKE 'mombasa port' THEN 'Mombasa Yard'
    WHEN LOWER(TRIM(Branch)) LIKE 'msa yard' THEN 'Mombasa Yard'
    WHEN LOWER(TRIM(Branch)) LIKE 'mombasa port yard' THEN 'Mombasa Yard'
-- For Nairobi
    WHEN LOWER(TRIM(Branch)) LIKE 'nairobi hq' THEN 'Main Yard'
 --For Nakuru
    WHEN LOWER(TRIM(Branch)) LIKE 'nkr yard' THEN 'Nakuru Yard'
    WHEN LOWER(TRIM(Branch)) LIKE 'nakuru branch'THEN 'Nakuru Yard'
-- For THIKA
    WHEN LOWER(TRIM(Branch)) LIKE 'thika branch' THEN 'Thika Yard'
    WHEN LOWER(TRIM(Branch)) LIKE 'thika' THEN 'Thika Yard'
    ELSE INITCAP(TRIM(Branch))::VARCHAR
END AS Branch, 
CASE
-- For Mary Wanjiku
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'mary' THEN 'Mary Wanjiku'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'mary wanj1ku' THEN 'Mary Wanjiku'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'mary  wanjiku' THEN 'Mary Wanjiku'
-- Foe Daniel Kimani
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'dan1El kimani' THEN 'Daniel Kimani'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'dan1el kimani' THEN 'Daniel Kimani'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'daniel  kimani' THEN 'Daniel Kimani'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'dan1el kimani' THEN 'Daniel Kimani'

    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'daniel' THEN 'Daniel Kimani'
-- For Mercy Atieno
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'mercy' THEN 'Mercy Atieno'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'mercy at1eno' THEN 'Mercy Atieno'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'mercy  atieno' THEN 'Mercy Atieno'
-- Foe Grace Njeri
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'grace' THEN 'Grace Njeri'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'grace njer1' THEN 'Grace Njeri'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'grace  njer1' THEN 'Grace Njeri'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'grace  njeri' THEN 'Grace Njeri'
-- For Faith Achieng
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'faith' THEN 'Faith Achieng'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'fa1th achieng' THEN 'Faith Achieng'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'faith  achieng' THEN 'Faith Achieng'
-- FOR Aisha Mohammed
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'aisha' THEN 'Aisha Mohamed'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'a1sha mohammed' THEN 'Aisha Mohamed'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'aisha mohammed' THEN 'Aisha Mohamed'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'a1sha mohamed' THEN 'Aisha Mohamed'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'aisha  mohamed' THEN 'Aisha Mohamed'

-- For Brian Otieno
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'brian' THEN 'Brian Otieno'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'br1an otieno' THEN 'Brian Otieno'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'brian  otieno' THEN 'Brian Otieno'
-- Foe Kevin Mwangi
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'kevin' THEN 'Kevin Mwangi'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'kev1n mwangi' THEN 'Kevin Mwangi'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'kevin  mwangi' THEN 'Kevin Mwangi'
-- For Peter Kiptoo
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'peter' THEN 'Peter Kiptoo'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'peter k1ptoo' THEN 'Peter Kiptoo'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'peter  kiptoo' THEN 'Peter Kiptoo'
-- For Samuel Mutua
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'samuel' THEN 'Samuel Mutua'
    WHEN LOWER(TRIM(Sales_Rep)) LIKE 'samuel  mutua' THEN 'Samuel Mutua'
    ELSE INITCAP(Sales_rep)::VARCHAR
END AS Sales_Rep, 
CASE
-- For Corporate tender
    WHEN LOWER(TRIM(lead_source)) LIKE 'corp tender' THEN 'Corporate Tender'
    WHEN LOWER(TRIM(lead_source)) LIKE 'corporate' THEN 'Corporate Tender'
    WHEN LOWER(TRIM(lead_source)) LIKE 'tender' THEN 'Corporate Tender'
-- For Facebook
-- For Facebook
    WHEN LOWER(TRIM(lead_source)) LIKE 'facebook' THEN 'Facebook'
    WHEN LOWER(TRIM(lead_source)) LIKE 'fb' THEN 'Facebook'
    WHEN LOWER(TRIM(lead_source)) LIKE 'face book' THEN 'Facebook'
-- For Instagram
    WHEN LOWER(TRIM(lead_source)) LIKE 'ig' THEN 'Instagram'
    WHEN LOWER(TRIM(lead_source)) LIKE 'insta' THEN 'Instagram'
-- For Phone call
    WHEN LOWER(TRIM(lead_source)) LIKE 'call' THEN 'Phone Call'
    WHEN LOWER(TRIM(lead_source)) LIKE 'phone' THEN 'Phone Call'
    WHEN LOWER(TRIM(lead_source)) LIKE 'phonecall' THEN 'Phone Call'
-- For Walk-in
    WHEN LOWER(TRIM(lead_source)) LIKE 'walk in' THEN 'Walk-In'
    WHEN LOWER(TRIM(lead_source)) LIKE 'walkin' THEN 'Walk-In'
-- For WhatsApp
    WHEN LOWER(TRIM(lead_source)) LIKE 'watsapp' THEN 'WhatsApp'
    WHEN LOWER(TRIM(lead_source)) LIKE 'whats app' THEN 'WhatsApp'
    WHEN LOWER(TRIM(lead_source)) LIKE 'whatsapp' THEN 'WhatsApp'
-- For Website
    WHEN LOWER(TRIM(lead_source)) LIKE 'site' THEN 'Website'
    WHEN LOWER(TRIM(lead_source)) LIKE 'web' THEN 'Website'
-- For Referral
    WHEN LOWER(TRIM(lead_source)) LIKE 'referal' THEN 'Referral'
    ELSE INITCAP(lead_source):: VARCHAR
END AS Lead_Sorce,
CASE
   -- For BMW
    WHEN LOWER(TRIM(car_make)) LIKE 'b.m.w' THEN 'BMW'
    WHEN LOWER(TRIM(car_make)) LIKE 'bmw' THEN 'BMW'
-- For Honda
    WHEN LOWER(TRIM(car_make)) LIKE 'honda' THEN 'Honda Motors' 
    WHEN LOWER(TRIM(car_make)) LIKE 'hondaa' THEN 'Honda Motors' 
-- For Isuzu
    WHEN LOWER(TRIM(car_make)) LIKE 'iszu' THEN 'Isuzu' 
-- For Mazda
    WHEN LOWER(TRIM(car_make)) LIKE 'mazada' THEN 'Mazda' 
-- For Merceds
    WHEN LOWER(TRIM(car_make)) LIKE 'mercedes benz' THEN 'Mercedes-Benz' 
    WHEN LOWER(TRIM(car_make)) LIKE 'mercedes' THEN 'Mercedes-Benz' 
    WHEN LOWER(TRIM(car_make)) LIKE 'benz' THEN 'Mercedes-Benz' 
-- For Mitsubishi
    WHEN LOWER(TRIM(car_make)) LIKE 'mitsubish' THEN 'Mitsubishi'
-- For Nissan
    WHEN LOWER(TRIM(car_make)) LIKE 'nisan' THEN 'Nissan'
-- For Subaru
    WHEN LOWER(TRIM(car_make)) LIKE 'subru' THEN 'Subaru'
-- For Toyota
    WHEN LOWER(TRIM(car_make)) LIKE 'toyta' THEN 'Toyota'
    WHEN LOWER(TRIM(car_make)) LIKE 'totoya' THEN 'Toyota'
    WHEN LOWER(TRIM(car_make)) LIKE 'toyota kenya' THEN 'Toyota'
-- For Volkswagen
    WHEN LOWER(TRIM(car_make)) LIKE 'v.w' THEN 'Volkswagen'
    WHEN LOWER(TRIM(car_make)) LIKE 'volks wagen' THEN 'Volkswagen'
    WHEN LOWER(TRIM(car_make)) LIKE 'vw' THEN 'Volkswagen'
    ELSE INITCAP(car_make)::VARCHAR

END AS car_make, 
CASE 
-- For 320i
    WHEN LOWER(TRIM(car_model)) LIKE '' THEN ''
-- For Atenza
-- For Axela
-- For Axio
-- For BMW X5
-- For CX-5
    WHEN LOWER(TRIM(car_model)) LIKE 'cx 5' THEN 'CX-5'
    WHEN LOWER(TRIM(car_model)) LIKE 'cx-5' THEN 'CX-5'
    WHEN LOWER(TRIM(car_model)) LIKE 'c x5' THEN 'CX-5'
-- For C-200
    WHEN LOWER(TRIM(car_model)) LIKE 'c200' THEN 'C-200'
-- For Canter
    WHEN LOWER(TRIM(car_model)) LIKE 'canter truck' THEN 'Canter Truck'
    WHEN LOWER(TRIM(car_model)) LIKE 'canter' THEN 'Canter Truck'
    WHEN LOWER(TRIM(car_model)) LIKE 'canterr' THEN 'Canter Truck'

-- For Corolla Altis
   WHEN LOWER(TRIM(car_model)) LIKE 'corolla' THEN 'Corolla Altis'
   WHEN LOWER(TRIM(car_model)) LIKE 'corola' THEN 'Corolla Altis'
    WHEN LOWER(TRIM(car_model)) LIKE 'corrola' THEN 'Corolla Altis'
-- For CR-V
    WHEN LOWER(TRIM(car_model)) LIKE 'cr-v' THEN 'CRV'
    WHEN LOWER(TRIM(car_model)) LIKE 'cr-v' THEN 'CRV'
    WHEN LOWER(TRIM(car_model)) LIKE 'crv' THEN 'CRV'
-- For D-MAX
    WHEN LOWER(TRIM(car_model)) LIKE 'd-max' THEN 'D-MAX'
     WHEN LOWER(TRIM(car_model)) LIKE 'd max' THEN 'D-MAX'
    WHEN LOWER(TRIM(car_model)) LIKE 'dmax' THEN 'D-MAX'
    WHEN LOWER(TRIM(car_model)) LIKE 'dmax pickup' THEN 'D-MAX'
-- For Demio
-- For E250
    WHEN LOWER(TRIM(car_model)) LIKE 'e-250' THEN 'E250'
-- For Fielder
    WHEN LOWER(TRIM(car_model)) LIKE 'fieldar' THEN 'Fielder'
-- For Fit
    WHEN LOWER(TRIM(car_model)) LIKE 'fit hybrid' THEN 'Fit Hybrid'
-- For Forester
    WHEN LOWER(TRIM(car_model)) LIKE 'forestar' THEN 'Forester'
-- For GLE
    WHEN LOWER(TRIM(car_model)) LIKE 'gle' THEN 'GLE'
-- For Golf
    WHEN LOWER(TRIM(car_model)) LIKE 'golf gti' THEN 'Golf'
-- For Harrier
    WHEN LOWER(TRIM(car_model)) LIKE 'Harier' THEN 'Harrier'
-- For HiAce
    WHEN LOWER(TRIM(car_model)) LIKE 'hiace' THEN 'HiAce'
    WHEN LOWER(TRIM(car_model)) LIKE 'hiece van' THEN 'HiAce'
    WHEN LOWER(TRIM(car_model)) LIKE 'hiace van' THEN 'HiAce'
    WHEN LOWER(TRIM(car_model)) LIKE 'hiece' THEN 'HiAce'

-- For Hilux
    WHEN LOWER(TRIM(car_model)) LIKE 'hillux' THEN 'Hilux'
-- For Imprezza
    WHEN LOWER(TRIM(car_model)) LIKE 'impreza' THEN 'Imprezza'
-- For Juke
-- For Land Cruiser
    WHEN LOWER(TRIM(car_model)) LIKE 'land-cruiser' THEN 'Land Cruiser Prado'
    WHEN LOWER(TRIM(car_model)) LIKE 'land cruiser' THEN 'Land Cruiser Prado'
    WHEN LOWER(TRIM(car_model)) LIKE 'landcruiser prado' THEN 'Land Cruiser Prado'
-- For Lc200
    WHEN LOWER(TRIM(car_model)) LIKE 'lc200' THEN 'LC200'
-- For Outback
    WHEN LOWER(TRIM(car_model)) LIKE 'out back' THEN 'Outback'
-- For Outlander
    WHEN LOWER(TRIM(car_model)) LIKE 'out lander' THEN 'Outlander'
-- For Prado TX
    WHEN LOWER(TRIM(car_model)) LIKE 'prado tx' THEN 'Prado TX'
    WHEN LOWER(TRIM(car_model)) LIKE 'prado-tx' THEN 'Prado TX'
-- For Vezel Hybrid
    WHEN LOWER(TRIM(car_model)) LIKE 'vezel' THEN 'Vezel Hybrid'
-- For X-Trail
    WHEN LOWER(TRIM(car_model)) LIKE 'xtrail' THEN 'X-Trail'
    WHEN LOWER(TRIM(car_model)) LIKE 'x trail' THEN 'X-Trail'
-- For X5
     WHEN LOWER(TRIM(car_model)) LIKE 'x-5' THEN 'X5'
-- For XV
    WHEN LOWER(TRIM(car_model)) LIKE 'xv' THEN 'XV'
    WHEN LOWER(TRIM(car_model)) LIKE 'subaru xv' THEN 'Prado '

    ELSE INITCAP(car_model)::VARCHAR
END AS car_model, 


NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(INITCAP(vehicle_type)), 'Suv', 'SUV'), '-', ''), ''):: VARCHAR AS vehicle_type, 
NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(vehicle_year, 'Twenty Twenty', '2020'), 'N/A', ''), ''), '202A', '2026'), '2032', ''), '')::INT AS vehicle_year, 
REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(INITCAP(fuel_type)), 'Dsl', 'Diesel'), 'Ev', 'Electric'), 'Hyb', 'Hybrid'), 'Hybridrid', 'Hybrid'), 'Pms', 'PMS')::VARCHAR AS fuel_type,
REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(INITCAP(transmission)), 'A/t', 'Automatic'), 'At', 'Automatic'), 'M/t', 'Manual'), 'Mt', 'Manual'), 'N/A', ''), '-', ''), ''), 'A/T', 'Automatic'), 'Auto', 'Automatic'), 'M/T', 'Manual'), 'Automaticmatic', 'Automatic')::VARCHAR  AS transmission,
REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(INITCAP(color)), 'Whi', 'White'), 'Gre', 'Green'), 'Sil' ,'Siver'), 'Blu', 'Blue'), 'Bla', 'Black'), '-', ''), ''), 'Blackck', 'Black'), 'Bluee', 'Blue'), 'Greenen', 'Green'), 'Greeny', 'Green'), 'Siverver', 'Silver'), 'Whitete', 'White')::VARCHAR AS Color,
CASE 
    -- 1. If it contains 'M', strip everything except digits/decimals, then multiply by 1,000,000
    WHEN UPPER(TRIM(unit_selling_price)) LIKE '%M%' 
        THEN TRY_TO_DECIMAL(REGEXP_REPLACE(TRIM(unit_selling_price), '[^0-9.]', ''), 38, 4) * 1000000

    -- 2. If it is already a full number, just strip out the currency text and commas
    ELSE TRY_TO_NUMERIC(REGEXP_REPLACE(TRIM(unit_selling_price), '[^0-9]', ''))
END AS unit_selling_price, 
CASE 
    -- 1. If it contains 'M', strip everything except digits/decimals, then multiply by 1,000,000
    WHEN UPPER(TRIM(unit_cost)) LIKE '%M%' 
        THEN TRY_TO_DECIMAL(REGEXP_REPLACE(TRIM(unit_cost), '[^0-9.]', ''), 38, 4) * 1000000

    -- 2. If it is already a full number, just strip out the currency text and commas
    ELSE TRY_TO_NUMERIC(REGEXP_REPLACE(TRIM(unit_cost), '[^0-9]', ''))
END AS unit_cost,
CASE 
    -- 1. Handle explicit strings/errors and turn them to NULL safely
    WHEN TRIM(discount) IN ('#ERROR', 'unkown', 'No Discount', 'Disc', '-', 'None', '') THEN NULL

    -- 2. If it is already a proper decimal between -1 and 1, keep it as is
    WHEN TRY_TO_DECIMAL(TRIM(discount), 38, 4) BETWEEN -1.0 AND 1.0 
        THEN TRY_TO_DECIMAL(TRIM(discount), 38, 4)

    -- 3. If it is a percentage (has '%', 'percent', or numbers > 1), strip text, keep signs/decimals, and divide by 100
    ELSE 
        TRY_TO_DECIMAL(
            REGEXP_REPLACE(TRIM(discount), '[^0-9.-]', ''), 
            38, 4
        ) / 100.0
END AS discount, 
 CASE 
    -- 1. If it contains 'M', strip everything except digits/decimals, then multiply by 1,000,000
    WHEN UPPER(TRIM(delivery_fee)) LIKE '%M%' 
        THEN TRY_TO_DECIMAL(REGEXP_REPLACE(TRIM(delivery_fee), '[^0-9.]', ''), 38, 4) * 1000000

    -- 2. If it is already a full number, just strip out the currency text and commas
    ELSE TRY_TO_NUMERIC(REGEXP_REPLACE(TRIM(delivery_fee), '[^0-9]', ''))
END AS delivery_fee, 

CASE
-- 1. Handle explicit strings/errors and turn them to NULL safely
    WHEN TRIM(logistics_cost) IN ('error', 'missing', 'not available', '#VALUE!', 'TBB', '') THEN NULL
 -- If it contains 'M', strip everything except digits/decimals, then multiply by 1,000,000
    WHEN UPPER(TRIM(logistics_cost)) LIKE '%M%' 
        THEN TRY_TO_DECIMAL(REGEXP_REPLACE(TRIM(logistics_cost), '[^0-9.]', ''), 38, 4) * 1000000
-- If it is already a full number, just strip out the currency text and commas
    ELSE TRY_TO_NUMERIC(REGEXP_REPLACE(TRIM(logistics_cost), '[^0-9]', ''))
END AS logistics_cost, 

NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(INITCAP(payment_method)), 'Mpesa', 'M-Pesa'), 'bank', 'bank transfer'), 'Asset Financing', 'Asset Finance'), 'Wire', 'Bank Transfer'), 'Bankers Cheque', 'Cheque'), 'Check', 'Cheque'), 'Rtgs', 'RTGS'), 'Bank', 'Bank Transfer'), 'M Pesa', 'M-Pesa'), 'Bank Transfer Transfer', 'Bank Transfer'), ''):: VARCHAR AS Payment_method,
REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(INITCAP(payment_status)), 'Refunded', 'Cancelled'), 'Paid', 'Complete'), 'Partially Paid', 'Deposit Paid'), 'Part Paid', 'Deposit Paid'), 'Refund', 'Cancelled'), 'Pending', 'Awaiting Payment'), 'Complete', 'Completed'), 'Partially Completed', 'Deposit Completed'), 'Cancel', 'Cancelled'), 'Partial', 'Deposit Completed'), 'Part Completed', 'Deposit Completed'), 'Completedd', 'Completed'), 'Unpaid', 'Awaiting Payment'), 'Cancelleded', 'Cancelled'), 'Cancelledled', 'Cancelled')::VARCHAR AS payment_status,
REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(INITCAP(delivery_status)), 'Transit', 'In-Transit'), 'Done', 'Delivered'), 'Delayed', 'At Yard'), 'At The Yard', 'At Yard'), 'Late','At Yard'), 'In Transit', 'In-Transit'), 'On The Way', 'In-Transit'), 'Held', 'At Yard'), 'Cancel', 'Cancelled'), 'In-In-Transit', 'In-Transit'), 'Cancelleded', 'Cancelled'), 'Cancelledled', 'Cancelled'), 'Yard', 'At Yard'), ''), 'In In-Transit', 'In-Transit'), 'At At Yard', 'At Yard'), 'Delivered', 'Completed')::VARCHAR AS delivery_status, 
TRY_TO_DECIMAL(
    CASE
        WHEN TRIM(customer_rating) LIKE '%out of 5%' THEN NULL
        WHEN TRIM(customer_rating) LIKE '%6' THEN '5'
        WHEN TRIM(customer_rating) LIKE '%/5%' THEN '5'
        WHEN TRIM(customer_rating) LIKE '%Excellent' THEN '5'
        ELSE REGEXP_REPLACE(TRIM(customer_rating), '[^0-9.]', '')
    END, 
    38, 1
) AS customer_rating,
NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(review_count), 'ten', '10'), '[^0-9]', ''), '')::INT AS review_count,
REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(NULLIF(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(INITCAP(TRIM(returned)), 'N', 'No'), 'Y', 'Yes'), 'Not Returned', 'No'), 'True', 'Yes'), 'False', 'No'), 'Returned', 'Yes'), '-', ''), ''), 'Noot Yes', 'Yes'), 'Yeses', 'Yes'), 'Noo', 'No')::VARCHAR AS returned, 

CASE
-- 1. Handle explicit strings/errors and turn them to NULL safely
    WHEN TRIM(revenue_recorded) IN ('error', 'missing', 'not available', '') THEN NULL
-- If it contains 'M', strip everything except digits/decimals, then multiply by 1,000,000
    WHEN UPPER(TRIM(revenue_recorded)) LIKE '%M%' 
        THEN TRY_TO_DECIMAL(REGEXP_REPLACE(TRIM(revenue_recorded), '[^0-9.]', ''), 38, 4) * 1000000
    -- If it is already a full number, just strip out the currency text and commas
    ELSE TRY_TO_NUMERIC(REGEXP_REPLACE(TRIM(revenue_recorded), '[^0-9]', ''))
END AS revenue_recorded
 












FROM source