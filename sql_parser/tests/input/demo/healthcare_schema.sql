
-- Table: patients
CREATE TABLE patients (
    patient_id UUID PRIMARY KEY,
    first_name TEXT,
    last_name TEXT,
    date_of_birth DATE,
    gender TEXT,
    race_ethnicity_id UUID,
    language_id UUID,
    address_id UUID,
    insurance_id UUID,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Table: visits
CREATE TABLE visits (
    visit_id UUID PRIMARY KEY,
    patient_id UUID,
    provider_id UUID,
    encounter_type_id UUID,
    visit_date DATE,
    admission_time TIMESTAMP,
    discharge_time TIMESTAMP,
    location TEXT,
    was_emergency BOOLEAN,
    reason_for_visit TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Table: providers
CREATE TABLE providers (
    provider_id UUID PRIMARY KEY,
    first_name TEXT,
    last_name TEXT,
    specialty TEXT,
    npi_number TEXT,
    location TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Table: encounter_types
CREATE TABLE encounter_types (
    encounter_type_id UUID PRIMARY KEY,
    encounter_type_name TEXT,
    description TEXT
);

-- Table: diagnoses
CREATE TABLE diagnoses (
    diagnosis_id UUID PRIMARY KEY,
    visit_id UUID,
    diagnosis_code TEXT,
    diagnosis_description TEXT,
    diagnosis_type TEXT,
    diagnosis_date DATE,
    created_at TIMESTAMP
);

-- Table: procedures
CREATE TABLE procedures (
    procedure_id UUID PRIMARY KEY,
    visit_id UUID,
    procedure_code TEXT,
    procedure_description TEXT,
    procedure_date DATE,
    created_at TIMESTAMP
);

-- Table: medications
CREATE TABLE medications (
    medication_id UUID PRIMARY KEY,
    visit_id UUID,
    medication_name TEXT,
    medication_code TEXT,
    dosage TEXT,
    route TEXT,
    frequency TEXT,
    start_date DATE,
    end_date DATE,
    created_at TIMESTAMP
);

-- Table: labs
CREATE TABLE labs (
    lab_result_id UUID PRIMARY KEY,
    visit_id UUID,
    test_name TEXT,
    test_code TEXT,
    result_value FLOAT,
    result_unit TEXT,
    reference_range TEXT,
    result_flag TEXT,
    collected_date DATE,
    reported_date DATE
);

-- Table: vitals
CREATE TABLE vitals (
    vital_id UUID PRIMARY KEY,
    visit_id UUID,
    height_cm FLOAT,
    weight_kg FLOAT,
    bmi FLOAT,
    blood_pressure_systolic INT,
    blood_pressure_diastolic INT,
    heart_rate INT,
    respiratory_rate INT,
    temperature_c FLOAT,
    recorded_at TIMESTAMP
);

-- Table: imaging
CREATE TABLE imaging (
    imaging_id UUID PRIMARY KEY,
    visit_id UUID,
    imaging_type TEXT,
    body_part TEXT,
    findings TEXT,
    impression TEXT,
    performed_date DATE
);

-- Table: allergies
CREATE TABLE allergies (
    allergy_id UUID PRIMARY KEY,
    patient_id UUID,
    allergen TEXT,
    reaction TEXT,
    severity TEXT,
    recorded_date DATE
);

-- Table: symptoms
CREATE TABLE symptoms (
    symptom_id UUID PRIMARY KEY,
    visit_id UUID,
    symptom TEXT,
    severity TEXT,
    onset_date DATE,
    resolved_date DATE
);

-- Table: conditions
CREATE TABLE conditions (
    condition_id UUID PRIMARY KEY,
    patient_id UUID,
    condition_name TEXT,
    condition_status TEXT,
    diagnosed_date DATE,
    resolved_date DATE
);

-- Table: claims
CREATE TABLE claims (
    claim_id UUID PRIMARY KEY,
    patient_id UUID,
    visit_id UUID,
    claim_status TEXT,
    claim_amount FLOAT,
    billed_amount FLOAT,
    paid_amount FLOAT,
    claim_date DATE
);

-- Table: billing
CREATE TABLE billing (
    billing_id UUID PRIMARY KEY,
    claim_id UUID,
    service_code TEXT,
    description TEXT,
    amount FLOAT,
    billed_date DATE
);

-- Table: payments
CREATE TABLE payments (
    payment_id UUID PRIMARY KEY,
    claim_id UUID,
    payment_source TEXT,
    amount FLOAT,
    payment_date DATE
);

-- Table: insurance
CREATE TABLE insurance (
    insurance_id UUID PRIMARY KEY,
    payer_name TEXT,
    plan_type TEXT,
    group_number TEXT,
    member_id TEXT,
    effective_date DATE,
    expiration_date DATE
);

-- Table: sdoh_entries
CREATE TABLE sdoh_entries (
    sdoh_id UUID PRIMARY KEY,
    patient_id UUID,
    sdoh_type TEXT,
    description TEXT,
    recorded_date DATE
);

-- Table: housing_status
CREATE TABLE housing_status (
    housing_id UUID PRIMARY KEY,
    patient_id UUID,
    housing_type TEXT,
    status_date DATE
);

-- Table: employment_status
CREATE TABLE employment_status (
    employment_id UUID PRIMARY KEY,
    patient_id UUID,
    employment_type TEXT,
    employer_name TEXT,
    status_date DATE
);

-- Table: income_brackets
CREATE TABLE income_brackets (
    income_id UUID PRIMARY KEY,
    patient_id UUID,
    income_level TEXT,
    source TEXT,
    recorded_date DATE
);

-- Table: addresses
CREATE TABLE addresses (
    address_id UUID PRIMARY KEY,
    street_address TEXT,
    city TEXT,
    state TEXT,
    postal_code TEXT,
    country TEXT
);

-- Table: languages
CREATE TABLE languages (
    language_id UUID PRIMARY KEY,
    language_name TEXT
);

-- Table: race_ethnicity
CREATE TABLE race_ethnicity (
    race_ethnicity_id UUID PRIMARY KEY,
    race_ethnicity_name TEXT
);

-- Table: surveys
CREATE TABLE surveys (
    survey_id UUID PRIMARY KEY,
    patient_id UUID,
    survey_type TEXT,
    survey_score INT,
    survey_date DATE
);

-- Table: screenings
CREATE TABLE screenings (
    screening_id UUID PRIMARY KEY,
    patient_id UUID,
    screening_type TEXT,
    result TEXT,
    screening_date DATE
);

-- Table: risk_scores
CREATE TABLE risk_scores (
    risk_score_id UUID PRIMARY KEY,
    patient_id UUID,
    score_type TEXT,
    score_value FLOAT,
    calculated_date DATE
);

-- Table: care_teams
CREATE TABLE care_teams (
    care_team_id UUID PRIMARY KEY,
    team_name TEXT,
    description TEXT
);

-- Table: patient_care_team
CREATE TABLE patient_care_team (
    patient_id UUID,
    care_team_id UUID,
    assigned_date DATE,
    PRIMARY KEY (patient_id, care_team_id)
);

-- Table: clinical_notes
CREATE TABLE clinical_notes (
    note_id UUID PRIMARY KEY,
    visit_id UUID,
    provider_id UUID,
    note_type TEXT,
    note_summary TEXT,
    note_text TEXT,
    created_at TIMESTAMP
);
