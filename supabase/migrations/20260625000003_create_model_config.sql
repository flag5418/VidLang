-- 本地模型配置表
-- 用于管理离线AI模型的版本和下载地址
CREATE TABLE model_config (
  id SERIAL PRIMARY KEY,
  model_type TEXT NOT NULL UNIQUE, -- 'llm', 'tts', 'stt'
  display_name TEXT NOT NULL, -- 显示名称
  repo TEXT NOT NULL, -- HuggingFace 仓库
  file_path TEXT NOT NULL, -- 文件路径
  file_size TEXT NOT NULL, -- 文件大小（人类可读）
  file_size_bytes BIGINT NOT NULL, -- 文件大小（字节）
  version TEXT NOT NULL, -- 版本号（用于强制更新）
  sha256 TEXT, -- 校验和
  is_required BOOLEAN DEFAULT TRUE, -- 是否必需
  is_active BOOLEAN DEFAULT TRUE, -- 是否启用
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 镜像配置表
CREATE TABLE model_mirror (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  is_default BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  priority INT DEFAULT 0, -- 优先级，数字越小优先级越高
  region TEXT, -- 适用地区（如 'cn', 'global'）
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 插入默认模型配置
INSERT INTO model_config (model_type, display_name, repo, file_path, file_size, file_size_bytes, version, is_required) VALUES
('llm', 'TranslateGemma 4B（翻译/对话/出题）', 'google/TranslateGemma-4B-it-GGUF', 'TranslateGemma-4B-it-Q4_K_M.gguf', '2.5GB', 2684354560, '1.0.0', TRUE),
('tts', 'Piper TTS 英语语音', 'rhasspy/piper-voices', 'en/en_US/amy/medium/en_US-amy-medium.onnx', '63MB', 66000000, '1.0.0', TRUE),
('stt', 'Whisper 语音识别', 'ggerganov/whisper.cpp', 'ggml-small.en.bin', '150MB', 157000000, '1.0.0', TRUE);

-- 插入默认镜像配置
INSERT INTO model_mirror (name, url, is_default, priority, region) VALUES
('hf-mirror.com（推荐）', 'https://hf-mirror.com', TRUE, 1, 'cn'),
('上海交大镜像', 'https://mirror.sjtu.edu.cn/huggingface', FALSE, 2, 'cn'),
('ModelScope（阿里）', 'https://huggingface.modelscope.cn', FALSE, 3, 'cn'),
('HuggingFace 官方', 'https://huggingface.co', FALSE, 10, 'global');

-- 启用 RLS
ALTER TABLE model_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE model_mirror ENABLE ROW LEVEL SECURITY;

-- 允许所有用户读取（模型配置是公开的）
CREATE POLICY "Allow public read model_config" ON model_config
  FOR SELECT USING (true);

CREATE POLICY "Allow public read model_mirror" ON model_mirror
  FOR SELECT USING (true);

-- 只允许管理员修改
CREATE POLICY "Allow admin insert model_config" ON model_config
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Allow admin update model_config" ON model_config
  FOR UPDATE USING (auth.role() = 'service_role');

CREATE POLICY "Allow admin insert model_mirror" ON model_mirror
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Allow admin update model_mirror" ON model_mirror
  FOR UPDATE USING (auth.role() = 'service_role');

-- 添加注释
COMMENT ON TABLE model_config IS '本地AI模型配置表，用于管理离线模型的版本和下载信息';
COMMENT ON TABLE model_mirror IS '模型下载镜像配置表，用于管理国内镜像地址';
COMMENT ON COLUMN model_config.version IS '模型版本号，用于检测是否需要强制更新';
COMMENT ON COLUMN model_mirror.region IS '镜像适用地区：cn=中国，global=全球';
