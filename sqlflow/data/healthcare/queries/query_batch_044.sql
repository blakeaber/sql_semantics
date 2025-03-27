-- Query 1
WITH AgeGroup AS (
    SELECT 
        patient_id,
        CASE 
            WHEN age(date_of_birth) <= '20 years' THEN '0-20'
            WHEN age(date_of_birth) <= '40 years' THEN '21-40'
            WHEN age(date_of_birth) <= '60 years' THEN '41-60'
            ELSE '60+' 
        END AS age_group
    FROM patients
),
AgeCategory AS (
    SELECT 
        age_group, 
        COUNT(patient_id) AS total_patients
    FROM AgeGroup
    GROUP BY age_group
)
SELECT 
    ag.age_group,
    ac.total_patients,
    COUNT(v.visit_id) AS total_visits,
    AVG((extract(epoch FROM v.discharge_time) - extract(epoch FROM v.admission_time)) / 3600) AS avg_visit_duration_hrs
FROM visits v
JOIN AgeGroup ag ON v.patient_id = ag.patient_id
JOIN AgeCategory ac ON ag.age_group = ac.age_group
GROUP BY ag.age_group, ac.total_patients
HAVING COUNT(v.visit_id) > 5;

-- Query 2
WITH RecentVisits AS (
    SELECT 
        patient_id, 
        MAX(visit_date) AS last_visit_date
    FROM visits
    GROUP BY patient_id
)
SELECT 
    p.first_name,
    p.last_name,
    r.last_visit_date,
    COUNT(d.diagnosis_id) AS diagnosis_count
FROM patients p
JOIN RecentVisits r ON p.patient_id = r.patient_id
LEFT JOIN visits v ON p.patient_id = v.patient_id AND v.visit_date = r.last_visit_date
LEFT JOIN diagnoses d ON v.visit_id = d.visit_id
GROUP BY p.first_name, p.last_name, r.last_visit_date;

-- Query 3
WITH HighClaimPayments AS (
    SELECT 
        claim_id,
        paid_amount,
        ntile(4) OVER (ORDER BY paid_amount DESC) AS quartile
    FROM claims
)
SELECT 
    ip.patient_id,
    ip.income_level,
    COUNT(c.claim_id) AS claim_count
FROM income_brackets ip
JOIN claims c ON ip.patient_id = c.patient_id
JOIN HighClaimPayments hcp ON c.claim_id = hcp.claim_id
WHERE hcp.quartile = 1
GROUP BY ip.patient_id, ip.income_level
HAVING COUNT(c.claim_id) > 3;

-- Query 4
WITH PatientVisitCounts AS (
    SELECT 
        v.patient_id,
        COUNT(v.visit_id) AS total_visits,
        SUM(CASE WHEN v.was_emergency THEN 1 ELSE 0 END) AS emergency_visits
    FROM visits v
    GROUP BY v.patient_id
)
SELECT 
    e.employment_type,
    p.total_visits,
    p.emergency_visits
FROM employment_status e
JOIN PatientVisitCounts p ON e.patient_id = p.patient_id
WHERE p.total_visits > 10 AND p.emergency_visits > 2
ORDER BY e.employment_type;

-- Query 5
WITH LastPaymentInfo AS (
    SELECT 
        claim_id,
        MAX(payment_date) AS last_payment_date
    FROM payments
    GROUP BY claim_id
)
SELECT 
    c.claim_status,
    b.service_code,
    SUM(b.amount) AS total_billed,
    COALESCE(SUM(p.amount), 0) AS total_paid,
    lpi.last_payment_date
FROM claims c
JOIN billing b ON c.claim_id = b.claim_id
LEFT JOIN LastPaymentInfo lpi ON c.claim_id = lpi.claim_id
LEFT JOIN payments p ON c.claim_id = p.claim_id AND p.payment_date = lpi.last_payment_date
GROUP BY c.claim_status, b.service_code, lpi.last_payment_date;

-- Query 6
WITH PatientLanguageMatch AS (
    SELECT 
        p.patient_id,
        CASE 
            WHEN l.language_name = 'English' THEN 1
            ELSE 0 
        END AS english_speaker
    FROM patients p
    JOIN languages l ON p.language_id = l.language_id
)
SELECT 
    pm.patient_id,
    COUNT(s.screening_type) AS number_of_screenings,
    AVG(rs.score_value) AS average_risk_score
FROM PatientLanguageMatch pm
JOIN screenings s ON pm.patient_id = s.patient_id
JOIN risk_scores rs ON pm.patient_id = rs.patient_id
WHERE pm.english_speaker = 1
GROUP BY pm.patient_id
HAVING COUNT(s.screening_type) > 1;

-- Query 7
WITH SpecializedProviders AS (
    SELECT 
        provider_id,
        specialty
    FROM providers
    WHERE specialty IN ('Cardiology', 'Neurology')
)
SELECT 
    sp.specialty,
    e.encounter_type_name,
    COUNT(DISTINCT v.visit_id) AS num_specialized_visits
FROM visits v
JOIN SpecializedProviders sp ON v.provider_id = sp.provider_id
JOIN encounter_types e ON v.encounter_type_id = e.encounter_type_id
GROUP BY sp.specialty, e.encounter_type_name
HAVING COUNT(DISTINCT v.visit_id) > 5;

-- Query 8
WITH AddressInfo AS (
    SELECT 
        a.patient_id,
        CONCAT(aa.city, ', ', aa.state) AS location
    FROM patients a
    JOIN addresses aa ON a.address_id = aa.address_id
)
SELECT 
    ai.location,
    COUNT(sa.survey_id) AS num_surveys,
    AVG(sa.survey_score) AS avg_survey_score
FROM AddressInfo ai
LEFT JOIN surveys sa ON ai.patient_id = sa.patient_id
GROUP BY ai.location
HAVING COUNT(sa.survey_id) > 5;

-- Query 9
WITH LabResultsSummary AS (
    SELECT 
        visit_id,
        COUNT(lab_result_id) AS num_results,
        AVG(result_value) AS avg_result_value
    FROM labs
    GROUP BY visit_id
)
SELECT 
    c.patient_id,
    lr.num_results,
    lr.avg_result_value,
    COUNT(DISTINCT v.vital_id) AS num_vitals
FROM LabResultsSummary lr
JOIN visits v ON lr.visit_id = v.visit_id
JOIN claims c ON v.visit_id = c.visit_id
GROUP BY c.patient_id, lr.num_results, lr.avg_result_value
HAVING lr.avg_result_value > 100;

-- Query 10
WITH PatientAllergySeverity AS (
    SELECT 
        patient_id,
        MAX(severity) AS max_severity
    FROM allergies
    GROUP BY patient_id
)
SELECT 
    pa.patient_id,
    pa.max_severity,
    COUNT(pro.procedure_id) AS num_procedures,
    SUM(labs.result_value) FILTER (WHERE labs.result_flag = 'High') AS sum_high_results
FROM PatientAllergySeverity pa
JOIN procedures pro ON pa.patient_id = pro.patient_id
JOIN visits v ON pro.visit_id = v.visit_id
LEFT JOIN labs ON v.visit_id = labs.visit_id
GROUP BY pa.patient_id, pa.max_severity;