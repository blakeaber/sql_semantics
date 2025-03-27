-- Query 1
WITH recent_visits AS (
    SELECT v.visit_id, v.patient_id, v.visit_date
    FROM visits v
    WHERE v.visit_date > CURRENT_DATE - INTERVAL '1 year'
)

SELECT p.patient_id, 
       COUNT(DISTINCT i.imaging_id) OVER(PARTITION BY p.patient_id) AS total_imaging,
       AVG(lab.result_value) AS avg_lab_result
FROM patients p
JOIN recent_visits rv ON p.patient_id = rv.patient_id
JOIN imaging i ON rv.visit_id = i.visit_id
JOIN labs lab ON rv.visit_id = lab.visit_id
WHERE lab.result_flag = 'abnormal'
GROUP BY p.patient_id
HAVING AVG(lab.result_value) > (
    SELECT AVG(lab2.result_value) 
    FROM labs lab2
    WHERE lab2.result_flag = 'normal'
)

-- Query 2
WITH age_groups AS (
    SELECT patient_id, 
           EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) AS age
    FROM patients
),
high_risk_patients AS (
    SELECT patient_id 
    FROM risk_scores
    WHERE score_value > 80
)

SELECT ag.age,
       COUNT(DISTINCT v.visit_id) AS num_visits,
       MAX(bp.billed_amount) AS max_billed_amount
FROM age_groups ag
JOIN visits v ON ag.patient_id = v.patient_id
JOIN claims c ON v.visit_id = c.visit_id
JOIN billing bp ON c.claim_id = bp.claim_id
WHERE ag.age BETWEEN 30 AND 60
AND ag.patient_id IN (SELECT patient_id FROM high_risk_patients)
GROUP BY ag.age

-- Query 3
WITH vital_trends AS (
    SELECT visit_id, 
           DENSE_RANK() OVER(PARTITION BY patient_id ORDER BY recorded_at DESC) as rn
    FROM vitals
)

SELECT pt.patient_id, 
       AVG(v.height_cm) AS average_height,
       SUM(CASE WHEN v.weight_kg > 100 THEN 1 ELSE 0 END) AS overweight_count
FROM patients pt
JOIN visits vs ON pt.patient_id = vs.patient_id
JOIN vital_trends vt ON vs.visit_id = vt.visit_id
JOIN vitals v ON vt.visit_id = v.visit_id
WHERE vt.rn = 1
GROUP BY pt.patient_id

-- Query 4
WITH child_visits AS (
    SELECT patient_id, 
           EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) AS age,
           visit_id
    FROM patients 
    JOIN visits ON patients.patient_id = visits.patient_id
    WHERE EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) < 18
)

SELECT cv.age AS child_age, 
       et.encounter_type_name,
       COUNT(cv.visit_id) AS visit_count
FROM child_visits cv
JOIN visits v ON cv.visit_id = v.visit_id
JOIN encounter_types et ON v.encounter_type_id = et.encounter_type_id
GROUP BY cv.age, et.encounter_type_name

-- Query 5
WITH insurance_payers AS (
    SELECT DISTINCT insurance_id, payer_name 
    FROM insurance
)

SELECT ip.payer_name,
       pt.gender,
       COUNT(v.visit_id) AS visit_count,
       ROUND(AVG(DATE_PART('day', v.discharge_time - v.admission_time)), 2) AS avg_length_of_stay
FROM insurance_payers ip
JOIN patients pt ON ip.insurance_id = pt.insurance_id
JOIN visits v ON pt.patient_id = v.patient_id
GROUP BY ip.payer_name, pt.gender

-- Query 6
WITH allergy_severity AS (
    SELECT patient_id,
           MAX(CASE severity WHEN 'Severe' THEN 3 WHEN 'Moderate' THEN 2 ELSE 1 END) AS max_severity
    FROM allergies
    GROUP BY patient_id
)

SELECT ls.lab_result_id,
       ls.visit_id,
       p.first_name || ' ' || p.last_name AS patient_name,
       ALLER.max_severity
FROM labs ls
JOIN visits vs ON ls.visit_id = vs.visit_id
JOIN patients p ON vs.patient_id = p.patient_id
LEFT JOIN allergy_severity ALLER ON p.patient_id = ALLER.patient_id
WHERE ls.result_flag = 'abnormal'
ORDER BY ALLER.max_severity DESC

-- Query 7
WITH chronic_conditions AS (
    SELECT patient_id, 
           COUNT(condition_id) AS condition_count
    FROM conditions
    WHERE condition_status = 'chronic'
    GROUP BY patient_id
)

SELECT cc.patient_id,
       cc.condition_count,
       SUM(c.paid_amount) AS total_paid,
       COUNT(DISTINCT r.risk_score_id) AS risk_assessments
FROM chronic_conditions cc
JOIN claims c ON cc.patient_id = c.patient_id
LEFT JOIN risk_scores r ON cc.patient_id = r.patient_id
GROUP BY cc.patient_id, cc.condition_count

-- Query 8
WITH recent_procedures AS (
    SELECT DISTINCT patient_id, 
                    procedure_code, 
                    MAX(procedure_date) AS last_procedure_date
    FROM procedures
    GROUP BY patient_id, procedure_code
)

SELECT rp.patient_id,
       rp.procedure_code,
       COUNT(DISTINCT sm.symptom_id) AS related_symptoms,
       IFNULL(rp.last_procedure_date, 'N/A') AS last_procedure_date
FROM recent_procedures rp
LEFT JOIN symptoms sm ON rp.patient_id = sm.patient_id
GROUP BY rp.patient_id, rp.procedure_code, rp.last_procedure_date

-- Query 9
WITH income_analysis AS (
    SELECT patient_id,
           MAX(CASE WHEN income_level = 'High' THEN 1 ELSE 0 END) AS is_high_income
    FROM income_brackets
    GROUP BY patient_id
)

SELECT ia.is_high_income,
       COUNT(DISTINCT pt.patient_id) AS patient_count,
       AVG(rs.score_value) AS avg_risk_score,
       SUM(cs.claim_amount) OVER() AS total_claim_amount
FROM income_analysis ia
LEFT JOIN patients pt ON ia.patient_id = pt.patient_id
LEFT JOIN risk_scores rs ON pt.patient_id = rs.patient_id
JOIN claims cs ON pt.patient_id = cs.patient_id
GROUP BY ia.is_high_income

-- Query 10
WITH language_diversity AS (
    SELECT p.language_id,
           COUNT(DISTINCT p.patient_id) AS num_patients
    FROM patients p
    GROUP BY p.language_id
    HAVING COUNT(DISTINCT p.patient_id) > 10
)

SELECT ld.language_id,
       ln.language_name,
       COUNT(DISTINCT s.survey_id) AS surveys_completed,
       MIN(vs.visit_date) AS first_visit_date
FROM language_diversity ld
JOIN languages ln ON ld.language_id = ln.language_id
LEFT JOIN surveys s ON ld.language_id = s.language_id
JOIN visits vs ON ld.language_id = vs.language_id
GROUP BY ld.language_id, ln.language_name