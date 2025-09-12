CREATE TABLE IF NOT EXISTS ds_props (
    propid INT AUTO_INCREMENT PRIMARY KEY,
    properties TEXT NOT NULL,
    citizenid VARCHAR(50) NOT NULL,
    proptype VARCHAR(50) NOT NULL
);
