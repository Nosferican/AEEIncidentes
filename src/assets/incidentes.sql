CREATE TABLE IF NOT EXISTS aeepr.incidentes
(
    statustime timestamp,
    area character varying(13),
    zone text,
    PRIMARY KEY (statustime, area, zone)
);

ALTER TABLE aeepr.incidentes
    OWNER to jbs3hp;
