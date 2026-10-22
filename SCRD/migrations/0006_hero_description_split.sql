-- Split the approved hero copy into the subtitle and supporting description fields.
-- Only normalize the known bundled defaults; preserve CMS-authored custom copy.
UPDATE system_config
SET config_value='"Kết nối tri thức học thuật, khảo thí chuẩn hóa và sáng kiến cộng đồng bền vững."', updated_at=CURRENT_TIMESTAMP
WHERE config_key='hero_subtitle_vi'
  AND config_value IN (
    'Kết nối tri thức học thuật, khảo thí chuẩn hóa và sáng kiến cộng đồng bền vững. Nền tảng chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
    '"Kết nối tri thức học thuật, khảo thí chuẩn hóa và sáng kiến cộng đồng bền vững. Nền tảng chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First."'
  );
UPDATE system_config
SET config_value='"Connecting academic knowledge, standardized assessment, and sustainable community initiatives."', updated_at=CURRENT_TIMESTAMP
WHERE config_key='hero_subtitle_en'
  AND config_value IN (
    'Connecting academic knowledge, standardized assessment, and sustainable community initiatives. The official platform of Sky First Center for Research and Development.',
    '"Connecting academic knowledge, standardized assessment, and sustainable community initiatives. The official platform of Sky First Center for Research and Development."'
  );
INSERT OR IGNORE INTO system_config(config_key,config_value,is_public,updated_at)
VALUES
('hero_description_vi','"Nền tảng chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First."',1,CURRENT_TIMESTAMP),
('hero_description_en','"The official platform of Sky First Center for Research and Development."',1,CURRENT_TIMESTAMP);
