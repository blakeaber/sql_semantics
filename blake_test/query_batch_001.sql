-- Query 1: Patient's Summary with Multi-layer Aggregation
WITH PatientAge AS (
    SELECT patient_id, 
           EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) AS age
    FROM patients
)
SELECT p.patient_id, 
       p.first_name, 
       p.last_name, 
       AVG(v.billed_amount) AS avg_billed_amount, 
       rs.avg_risk_score
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN claims c ON v.visit_id = c.visit_id
JOIN (
    SELECT patient_id, 
           AVG(score_value) AS avg_risk_score
    FROM risk_scores
    WHERE score_type = 'General'
    GROUP BY patient_id
) rs ON p.patient_id = rs.patient_id
WHERE p.patient_id IN (
    SELECT patient_id
    FROM housing_status
    WHERE housing_type = 'Rented'
)
GROUP BY p.patient_id, rs.avg_risk_score
HAVING COUNT(c.claim_id) > 3;

-- Query 2: Utilization Patterns and Health Outcomes
WITH VisitsCount AS (
    SELECT patient_id,
           COUNT(visit_id) AS total_visits
    FROM visits
    GROUP BY patient_id
)
SELECT p.first_name, 
       p.last_name, 
       vc.total_visits, 
       CASE WHEN h.housing_type IS NOT NULL THEN h.housing_type ELSE 'Unknown' END AS housing_type,
       i.impression
FROM patients p
JOIN VisitsCount vc ON p.patient_id = vc.patient_id
JOIN imaging i ON p.patient_id = i.visit_id
LEFT JOIN housing_status h ON p.patient_id = h.patient_id
WHERE i.impression IN (
    SELECT impression
    FROM imaging
    WHERE body_part = 'Chest'
    GROUP BY impression
    HAVING COUNT(imaging_id) > 2
);

-- Query 3: Multi-domain Health Indicators
WITH RecentScreenings AS (
    SELECT patient_id, 
           screening_type, 
           MAX(screening_date) AS last_screening_date
    FROM screenings
    GROUP BY patient_id, screening_type
)
SELECT p.first_name, 
       p.last_name, 
       s.screening_type, 
       v.bmi,
       AVG(m.result_value) OVER (PARTITION BY v.visit_id) AS avg_lab_result
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN vitals vi ON v.visit_id = vi.visit_id
JOIN RecentScreenings s ON p.patient_id = s.patient_id
JOIN labs m ON v.visit_id = m.visit_id
WHERE s.last_screening_date > '2020-01-01'
AND m.test_name = 'Hemoglobin';

-- Query 4: Provider Impact and Patient Flow
WITH DiagnosisCount AS (
    SELECT provider_id, 
           COUNT(diagnosis_id) AS diagnosis_count
    FROM diagnoses
    GROUP BY provider_id
)
SELECT pr.first_name AS provider_first_name, 
       pr.last_name AS provider_last_name, 
       AVG(d.diagnosis_count) AS avg_diagnosis_count,
       SUM(CASE WHEN c.claim_status = 'Paid' THEN 1 ELSE 0 END) AS paid_claims_count
FROM providers pr
JOIN visits v ON pr.provider_id = v.provider_id
JOIN DiagnosisCount d ON pr.provider_id = d.provider_id
JOIN claims c ON v.visit_id = c.visit_id
GROUP BY pr.provider_id
HAVING paid_claims_count > 10;

-- Query 5: Chronic Conditions and Socioeconomic Factors
WITH ChronicPatients AS (
    SELECT patient_id, 
           condition_name
    FROM conditions
    WHERE condition_status = 'Active'
)
SELECT p.first_name, 
       p.last_name, 
       c.condition_name, 
       e.employment_type, 
       i.income_level,
       s.description AS sdoh_description
FROM patients p
JOIN ChronicPatients c ON p.patient_id = c.patient_id
JOIN employment_status e ON p.patient_id = e.patient_id
JOIN income_brackets i ON p.patient_id = i.patient_id
LEFT JOIN sdoh_entries s ON p.patient_id = s.patient_id
WHERE c.condition_name IN (
    SELECT DISTINCT condition_name 
    FROM ChronicPatients 
    WHERE patient_id = p.patient_id
);

-- Query 6: Emergency Visits and Outcomes Analysis
WITH EmergencyVisitDetails AS (
    SELECT visit_id, 
           patient_id, 
           admission_time
    FROM visits
    WHERE was_emergency = TRUE
)
SELECT evd.patient_id, 
       ROUND(AVG(EXTRACT(EPOCH FROM (discharge_time - admission_time)) / 3600), 2) AS avg_stay_hours,
       COUNT(DISTINCT d.diagnosis_id) AS num_diagnoses
FROM EmergencyVisitDetails evd
JOIN diagnoses d ON evd.visit_id = d.visit_id
JOIN patients p ON evd.patient_id = p.patient_id
GROUP BY evd.patient_id
HAVING num_diagnoses > 2;

-- Query 7: Medication Usage Trends
WITH MedicationUsage AS (
    SELECT visit_id, 
           COUNT(medication_id) AS medication_count
    FROM medications
    WHERE start_date > '2021-01-01'
    GROUP BY visit_id
)
SELECT p.first_name, 
       p.last_name, 
       m.medication_name, 
       m.dosage, 
       mu.medication_count
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN MedicationUsage mu ON v.visit_id = mu.visit_id
JOIN medications m ON v.visit_id = m.visit_id
WHERE m.medication_name IN (
    SELECT medication_name
    FROM medications
    GROUP BY medication_name
    HAVING COUNT(DISTINCT visit_id) > 5
);

-- Query 8: Cross-sectional Patient Insights
WITH VitalsSummary AS (
    SELECT patient_id, 
           AVG(bmi) AS avg_bmi
    FROM vitals
    GROUP BY patient_id
)
SELECT p.first_name, 
       p.last_name, 
       v.avg_bmi, 
       CASE 
           WHEN r.race_ethnicity_name IS NOT NULL THEN r.race_ethnicity_name 
           ELSE 'Unknown' 
       END AS race_ethnicity
FROM patients p
JOIN VitalsSummary v ON p.patient_id = v.patient_id
LEFT JOIN race_ethnicity r ON p.race_ethnicity_id = r.race_ethnicity_id
WHERE v.avg_bmi > (
    SELECT AVG(avg_bmi) 
    FROM VitalsSummary
);

-- Query 9: Provider and Insurance Collaboration
WITH ProviderClaimSummary AS (
    SELECT prov.provider_id,
           COUNT(DISTINCT cl.claim_id) AS total_claims,
           SUM(cl.paid_amount) AS total_paid
    FROM providers prov
    JOIN visits vis ON prov.provider_id = vis.provider_id
    JOIN claims cl ON vis.visit_id = cl.visit_id
    GROUP BY prov.provider_id
)
SELECT prov.first_name, 
       prov.last_name, 
       pcs.total_claims, 
       pcs.total_paid, 
       COUNT(DISTINCT ins.insurance_id) AS unique_insurers
FROM ProviderClaimSummary pcs
JOIN providers prov ON pcs.provider_id = prov.provider_id
JOIN insurance ins ON prov.provider_id = ins.insurance_id
GROUP BY prov.provider_id, pcs.total_claims, pcs.total_paid
HAVING unique_insurers > 1;

-- Query 10: Demographic Health Disparities
WITH RaceDiagnosisSummary AS (
    SELECT p.race_ethnicity_id, 
           COUNT(diagnosis_id) AS diagnosis_count
    FROM patients p
    JOIN visits v ON p.patient_id = v.patient_id
    JOIN diagnoses d ON v.visit_id = d.visit_id
    GROUP BY p.race_ethnicity_id
)
SELECT re.race_ethnicity_name, 
       AVG(rds.diagnosis_count) AS avg_diagnoses,
       SUM(CASE WHEN s.survey_type = 'Health' THEN 1 ELSE 0 END) AS health_survey_participation
FROM RaceDiagnosisSummary rds
JOIN race_ethnicity re ON rds.race_ethnicity_id = re.race_ethnicity_id
LEFT JOIN surveys s ON rds.race_ethnicity_id = s.patient_id
GROUP BY re.race_ethnicity_name
HAVING avg_diagnoses > 10;