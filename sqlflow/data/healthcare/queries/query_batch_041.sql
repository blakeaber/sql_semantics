WITH PatientVisitCTE AS (
    SELECT p.patient_id, v.visit_id, v.visit_date, v.was_emergency, v.location
    FROM patients p
    JOIN visits v ON p.patient_id = v.patient_id
    WHERE v.visit_date > '2023-01-01'
),
ProviderSpecialtyCTE AS (
    SELECT provider_id, specialty, COUNT(*) AS visit_count
    FROM providers pr
    JOIN visits vi ON pr.provider_id = vi.provider_id
    GROUP BY provider_id, specialty
    HAVING COUNT(*) > 5
)
SELECT pv.patient_id, pv.visit_id, pv.visit_date, pr.first_name, pr.last_name, pr.specialty,
       et.encounter_type_name, d.diagnosis_code, d.diagnosis_description,
       CASE
           WHEN pv.was_emergency = TRUE THEN 'Emergency'
           ELSE 'Non-Emergency'
       END AS emergency_status,
       RANK() OVER (PARTITION BY pv.patient_id ORDER BY pv.visit_date DESC) AS visit_rank
FROM PatientVisitCTE pv
JOIN ProviderSpecialtyCTE ps ON ps.provider_id = pv.provider_id
JOIN providers pr ON pv.provider_id = pr.provider_id
JOIN encounter_types et ON pv.encounter_type_id = et.encounter_type_id
LEFT JOIN (
    SELECT DISTINCT ON (visit_id) visit_id, diagnosis_code, diagnosis_description
    FROM diagnoses
    WHERE diagnosis_date > '2023-01-01'
    ORDER BY visit_id, diagnosis_date DESC
) d ON pv.visit_id = d.visit_id
JOIN (
    SELECT v1.visit_id, v1.patient_id, MAX(v1.visit_date) AS last_visit_date
    FROM visits v1
    JOIN diagnoses d1 ON v1.visit_id = d1.visit_id
    WHERE d1.diagnosis_type IN ('Chronic', 'Acute')
    GROUP BY v1.visit_id, v1.patient_id
) sub_query ON pv.patient_id = sub_query.patient_id AND pv.visit_date = sub_query.last_visit_date
ORDER BY pv.patient_id, visit_rank;

WITH HighRiskPatients AS (
    SELECT p.patient_id, MAX(rs.score_value) AS max_risk_score
    FROM patients p
    JOIN risk_scores rs ON p.patient_id = rs.patient_id
    WHERE rs.calculated_date BETWEEN '2022-01-01' AND '2023-01-01'
    GROUP BY p.patient_id
    HAVING MAX(rs.score_value) > 75
),
RecentClaims AS (
    SELECT DISTINCT ON (c.claim_id) c.claim_id, c.patient_id, c.claim_date, c.claim_status, c.claim_amount
    FROM claims c
    WHERE c.claim_date > '2023-01-01'
    ORDER BY c.claim_id, c.claim_date DESC
)
SELECT hrp.patient_id, hrp.max_risk_score, rc.claim_id, rc.claim_date, rc.claim_status,
       COALESCE(SUM(pg.amount), 0) AS total_payments,
       COALESCE(SUM(bl.amount), 0) AS total_billed
FROM HighRiskPatients hrp
JOIN RecentClaims rc ON hrp.patient_id = rc.patient_id
LEFT JOIN payments pg ON rc.claim_id = pg.claim_id
LEFT JOIN billing bl ON rc.claim_id = bl.claim_id
WHERE rc.claim_status = 'Pending'
GROUP BY hrp.patient_id, hrp.max_risk_score, rc.claim_id, rc.claim_date, rc.claim_status
ORDER BY hrp.max_risk_score DESC, rc.claim_date;

WITH EmergencyVisits AS (
    SELECT vis.visit_id, vis.patient_id, COUNT(med.medication_id) AS med_count
    FROM visits vis
    JOIN medications med ON vis.visit_id = med.visit_id
    WHERE vis.was_emergency = TRUE
    GROUP BY vis.visit_id, vis.patient_id
),
StaleMedications AS (
    SELECT m.medication_id, m.visit_id, m.medication_name, m.start_date, m.end_date
    FROM medications m
    WHERE m.end_date IS NULL OR m.end_date > '2023-01-01'
)
SELECT ev.patient_id, count(DISTINCT ev.visit_id) as emergency_visit_count, avg_calculations.avg_bmi,
       st.medication_name
FROM EmergencyVisits ev
JOIN visits v ON ev.visit_id = v.visit_id
LEFT JOIN (
    SELECT vit.visit_id, AVG(vit.bmi) AS avg_bmi
    FROM vitals vit
    GROUP BY vit.visit_id
) avg_calculations ON ev.visit_id = avg_calculations.visit_id
LEFT JOIN procedures p ON ev.visit_id = p.visit_id
LEFT JOIN StaleMedications st ON ev.visit_id = st.visit_id
WHERE p.procedure_date IS NOT NULL
GROUP BY ev.patient_id, avg_calculations.avg_bmi, st.medication_name
HAVING count(DISTINCT ev.visit_id) > 3;

WITH ChronicConditions AS (
    SELECT condition_id, patient_id, condition_name, diagnosed_date
    FROM conditions
    WHERE condition_status = 'Chronic'
),
FrequentLabTests AS (
    SELECT l.visit_id, l.test_name, COUNT(l.lab_result_id) AS test_count
    FROM labs l
    GROUP BY l.visit_id, l.test_name
    HAVING COUNT(l.lab_result_id) > 3
)
SELECT cc.patient_id, cc.condition_name, FIRST_VALUE(l.count) OVER (PARTITION BY cc.patient_id ORDER BY l.count DESC) AS frequent_test_count
FROM ChronicConditions cc
JOIN FrequentLabTests l ON cc.patient_id = l.patient_id
JOIN visits v ON l.visit_id = v.visit_id
JOIN procedures pr ON v.visit_id = pr.visit_id
ORDER BY cc.condition_name, frequent_test_count DESC;

SELECT DISTINCT p.patient_id, AI.score_value, med.dosage, ins.payer_name,
       DENSE_RANK() OVER (PARTITION BY ins.payer_name ORDER BY AI.score_value DESC) AS payer_ranking
FROM patients p
JOIN diagnoses d ON p.patient_id = d.patient_id
JOIN medications med ON d.visit_id = med.visit_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN insurance ins ON p.insurance_id = ins.insurance_id
JOIN (
    SELECT patient_id, AVG(rs.score_value) AS score_value
    FROM risk_scores rs
    WHERE rs.calculated_date > '2023-01-01'
    GROUP BY patient_id
) AI ON p.patient_id = AI.patient_id
WHERE ins.expiration_date > '2023-01-01'
ORDER BY AI.score_value DESC;

WITH SmokingPatients AS (
    SELECT patient_id
    FROM sdoh_entries
    WHERE sdoh_type = 'Smoking' AND recorded_date > '2022-01-01'
),
ActiveAllergies AS (
    SELECT allergic_allergy.patient_id, allergen, MAX(recorded_date) AS latest_record
    FROM allergies allergic_allergy
    GROUP BY allergic_allergy.patient_id, allergen
    HAVING MAX(recorded_date) > '2023-01-01'
)
SELECT sp.patient_id, sp.visit_id, p.first_name, p.last_name,
       ag.allergen, ag.latest_record,
       AVG(vit.height_cm) OVER (PARTITION BY ag.patient_id) AS avg_height
FROM SmokingPatients sp
JOIN ActiveAllergies ag ON sp.patient_id = ag.patient_id
JOIN patients p ON sp.patient_id = p.patient_id
JOIN visits vis ON sp.patient_id = vis.patient_id
JOIN vitals vit ON vis.visit_id = vit.visit_id
LEFT JOIN procedures proc ON vis.visit_id = proc.visit_id
WHERE proc.procedure_date IS NOT NULL
ORDER BY ag.latest_record DESC, p.first_name, p.last_name;

WITH ActiveMedications AS (
    SELECT m.medication_id, m.visit_id, m.medication_name, m.start_date, m.end_date
    FROM medications m
    WHERE (m.end_date IS NULL OR m.end_date > '2023-01-01')
),
HeartRateLevel AS (
    SELECT v.visit_id, CASE
                        WHEN vit.heart_rate > 100 THEN 'High'
                        WHEN vit.heart_rate > 60 THEN 'Normal'
                        ELSE 'Low'
                        END AS heart_rate_level
    FROM vitals vit
    JOIN visits v ON vit.visit_id = v.visit_id
)
SELECT p.patient_id, am.medication_name, hr.heart_rate_level,
       EXTRACT(YEAR FROM AGE(p.date_of_birth)) AS patient_age
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN ActiveMedications am ON v.visit_id = am.visit_id
JOIN HeartRateLevel hr ON v.visit_id = hr.visit_id
LEFT JOIN (
    SELECT DISTINCT patient_id, sdoh_type
    FROM sdoh_entries
    WHERE sdoh_type IN ('Alcohol Use', 'Drug Use')
) sd ON p.patient_id = sd.patient_id
ORDER BY patient_age, am.medication_name, hr.heart_rate_level;

WITH RecentSurveys AS (
    SELECT s.patient_id, MAX(s.survey_score) AS max_score,
           SUM(s.survey_score) AS total_score,
           COUNT(s.survey_score) AS num_surveys
    FROM surveys s
    WHERE s.survey_date > '2023-01-01'
    GROUP BY s.patient_id
),
ScreeningParticipants AS (
    SELECT sc.patient_id, COUNT(sc.screening_id) AS screening_count
    FROM screenings sc
    WHERE sc.result = 'Positive'
    GROUP BY sc.patient_id
)
SELECT rs.patient_id, rs.max_score, sc.screening_count,
       ROUND(1.0 * rs.total_score / rs.num_surveys, 2) AS avg_survey_score
FROM RecentSurveys rs
JOIN ScreeningParticipants sc ON rs.patient_id = sc.patient_id
JOIN patients p ON rs.patient_id = p.patient_id
LEFT JOIN languages l ON p.language_id = l.language_id
LEFT JOIN insurance ins ON p.insurance_id = ins.insurance_id
ORDER BY avg_survey_score DESC, sc.screening_count;

WITH ClaimsSummary AS (
    SELECT cl.patient_id, SUM(cl.claim_amount) AS total_claims_amount
    FROM claims cl
    WHERE cl.claim_date > '2023-01-01'
    GROUP BY cl.patient_id
),
PaymentDetail AS (
    SELECT py.claim_id, SUM(py.amount) AS total_payment
    FROM payments py
    GROUP BY py.claim_id
)
SELECT cs.patient_id, cs.total_claims_amount, pd.total_payment,
       (cs.total_claims_amount - COALESCE(pd.total_payment, 0)) AS remaining_due,
       COUNT(cl.claim_id)
FROM ClaimsSummary cs
JOIN claims cl ON cs.patient_id = cl.patient_id
LEFT JOIN PaymentDetail pd ON cl.claim_id = pd.claim_id
LEFT JOIN (
    SELECT DISTINCT patient_id, condition_status
    FROM conditions
    WHERE condition_status = 'Remission'
) cd ON cs.patient_id = cd.patient_id
JOIN patients p ON cs.patient_id = p.patient_id
LEFT JOIN addresses a ON p.address_id = a.address_id
GROUP BY cs.patient_id, cs.total_claims_amount, pd.total_payment
ORDER BY remaining_due DESC;

WITH FrequentContactCTE AS (
    SELECT p.patient_id, pr.provider_id, COUNT(*) AS contact_count
    FROM visits v
    JOIN providers pr ON v.provider_id = pr.provider_id
    WHERE v.visit_date > '2023-01-01'
    GROUP BY p.patient_id, pr.provider_id
),
AverageVitals AS (
    SELECT v.visit_id, AVG(vit.bmi) AS avg_bmi, AVG(vit.temperature_c) AS avg_temp
    FROM vitals vit
    GROUP BY v.visit_id
)
SELECT fc.patient_id, pr.first_name AS provider_name, fc.contact_count, av.avg_bmi, av.avg_temp,
       CASE WHEN av.avg_temp > 37 THEN 'Fever' ELSE 'Normal' END AS temp_status
FROM FrequentContactCTE fc
JOIN providers pr ON fc.provider_id = pr.provider_id
JOIN visits v ON fc.patient_id = v.patient_id AND fc.provider_id = v.provider_id
JOIN AverageVitals av ON v.visit_id = av.visit_id
LEFT JOIN imaging im ON v.visit_id = im.visit_id
WHERE im.findings IS NOT NULL
ORDER BY temp_status DESC, fc.contact_count;
