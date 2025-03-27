-- Query 1
WITH RecentVisits AS (
    SELECT visit_id, patient_id, visit_date
    FROM visits
    WHERE visit_date > CURRENT_DATE - INTERVAL '1 year'
), 
PatientInfo AS (
    SELECT p.patient_id, p.first_name, p.last_name, re.race_ethnicity_name
    FROM patients p
    JOIN race_ethnicity re ON p.race_ethnicity_id = re.race_ethnicity_id
)
SELECT rv.visit_id, pi.first_name, pi.last_name, AVG(l.result_value) AS avg_lab_result
FROM RecentVisits rv
JOIN labs l ON rv.visit_id = l.visit_id
JOIN PatientInfo pi ON rv.patient_id = pi.patient_id
GROUP BY rv.visit_id, pi.first_name, pi.last_name
HAVING COUNT(l.lab_result_id) > 5;

-- Query 2
WITH CurrentMedications AS (
    SELECT m.medication_id, v.visit_id, m.medication_name
    FROM medications m
    INNER JOIN visits v ON m.visit_id = v.visit_id
    WHERE m.start_date <= CURRENT_DATE AND (m.end_date IS NULL OR m.end_date >= CURRENT_DATE)
)
SELECT p.patient_id, p.first_name, p.last_name, COUNT(cm.medication_id) AS current_medication_count
FROM patients p
LEFT JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN CurrentMedications cm ON v.visit_id = cm.visit_id
GROUP BY p.patient_id, p.first_name, p.last_name
HAVING COUNT(cm.medication_id) > 1;

-- Query 3
WITH HighRiskPatients AS (
    SELECT r.patient_id, AVG(r.score_value) AS avg_risk_score
    FROM risk_scores r
    WHERE r.calculated_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY r.patient_id
    HAVING AVG(r.score_value) > 7
), 
DiagnosisInfo AS (
    SELECT d.visit_id, d.diagnosis_code, COUNT(d.diagnosis_id) AS diagnosis_count
    FROM diagnoses d
    GROUP BY d.visit_id, d.diagnosis_code
)
SELECT hrp.patient_id, p.first_name, p.last_name, SUM(diagnosis_count) AS total_diagnoses
FROM HighRiskPatients hrp
JOIN patients p ON hrp.patient_id = p.patient_id
JOIN DiagnosisInfo di ON p.patient_id = di.visit_id
GROUP BY hrp.patient_id, p.first_name, p.last_name;

-- Query 4
WITH EmergencyVisits AS (
    SELECT visit_id, patient_id, was_emergency
    FROM visits
    WHERE was_emergency = TRUE
),
LanguageStats AS (
    SELECT l.language_name, COUNT(p.patient_id) AS patient_count
    FROM patients p
    JOIN languages l ON p.language_id = l.language_id
    GROUP BY l.language_name
)
SELECT ev.patient_id, lang.language_name, COUNT(ev.visit_id) AS emergency_visits
FROM EmergencyVisits ev
JOIN LanguageStats lang ON ev.patient_id = lang.patient_id
WHERE lang.patient_count > 50
GROUP BY ev.patient_id, lang.language_name;

-- Query 5
WITH FrequentVisitors AS (
    SELECT patient_id, COUNT(visit_id) AS visit_count
    FROM visits
    WHERE visit_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY patient_id
    HAVING COUNT(visit_id) > 5
),
ProcedureTypes AS (
    SELECT pr.procedure_code, COUNT(pr.procedure_id) AS procedure_frequency
    FROM procedures pr
    GROUP BY pr.procedure_code
)
SELECT fv.patient_id, p.first_name, p.last_name, proc.procedure_frequency
FROM FrequentVisitors fv
JOIN patients p ON fv.patient_id = p.patient_id
LEFT JOIN ProcedureTypes proc ON fv.patient_id = proc.procedure_code
WHERE proc.procedure_frequency > 10;

-- Query 6
WITH ConditionDuration AS (
    SELECT patient_id, condition_name, EXTRACT(DAY FROM COALESCE(resolved_date, CURRENT_DATE) - diagnosed_date) AS duration
    FROM conditions
),
HousingStatusCount AS (
    SELECT hs.patient_id, COUNT(hs.housing_id) AS status_changes
    FROM housing_status hs
    GROUP BY hs.patient_id
)
SELECT cd.patient_id, cd.condition_name, hs.status_changes
FROM ConditionDuration cd
JOIN HousingStatusCount hs ON cd.patient_id = hs.patient_id
WHERE cd.duration > 180;

-- Query 7
WITH PastDiagnoses AS (
    SELECT visit_id, diagnosis_code
    FROM diagnoses
    WHERE diagnosis_date < CURRENT_DATE - INTERVAL '2 years'
),
SurveyScores AS (
    SELECT patient_id, AVG(survey_score) AS avg_survey_score
    FROM surveys
    GROUP BY patient_id
)
SELECT pd.visit_id, pd.diagnosis_code, ss.avg_survey_score
FROM PastDiagnoses pd
JOIN SurveyScores ss ON pd.visit_id = ss.patient_id
WHERE ss.avg_survey_score > 80;

-- Query 8
WITH InsuranceActive AS (
    SELECT insurance_id, COUNT(patient_id) AS member_count
    FROM insurance
    WHERE expiration_date > CURRENT_DATE
    GROUP BY insurance_id
),
PaymentTotals AS (
    SELECT claim_id, SUM(amount) AS total_payment
    FROM payments
    WHERE payment_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY claim_id
)
SELECT ia.insurance_id, ia.member_count, pt.total_payment
FROM InsuranceActive ia
JOIN claims c ON ia.insurance_id = c.insurance_id
LEFT JOIN PaymentTotals pt ON c.claim_id = pt.claim_id
WHERE pt.total_payment > 10000;

-- Query 9
WITH VisitDetails AS (
    SELECT v.visit_id, v.patient_id, e.encounter_type_name
    FROM visits v
    JOIN encounter_types e ON v.encounter_type_id = e.encounter_type_id
),
VitalAverages AS (
    SELECT visit_id, AVG(height_cm) AS avg_height, AVG(weight_kg) AS avg_weight
    FROM vitals
    GROUP BY visit_id
)
SELECT vd.patient_id, vd.encounter_type_name, va.avg_height, va.avg_weight
FROM VisitDetails vd
LEFT JOIN VitalAverages va ON vd.visit_id = va.visit_id
WHERE va.avg_height IS NOT NULL;

-- Query 10
WITH SymptomOccurrences AS (
    SELECT visit_id, symptom, COUNT(symptom_id) AS symptom_count
    FROM symptoms
    GROUP BY visit_id, symptom
),
RecentClaims AS (
    SELECT patient_id, SUM(claim_amount) AS total_claims
    FROM claims
    WHERE claim_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY patient_id
)
SELECT so.visit_id, so.symptom, rc.total_claims
FROM SymptomOccurrences so
JOIN RecentClaims rc ON so.visit_id = rc.patient_id
ORDER BY rc.total_claims DESC;