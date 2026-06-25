 -- ============================================================
 -- 声通配置补充：uid + socket_server
 -- ============================================================

 INSERT INTO public.app_settings (key, value, description) VALUES
   ('shengtong_uid', 'uid', '声通评测 userId'),
   ('shengtong_socket_server', 'ws://api.stkouyu.com:8080/sent.eval', '声通 WebSocket 服务地址')
 ON CONFLICT (key) DO UPDATE SET
   value = excluded.value,
   description = excluded.description,
   updated_at = NOW();

 -- 确保 ai_audio_evaluation 计费规则存在
 INSERT INTO public.pricing_rule (rule_code, name_zh, description_zh, model, price_cny, status) VALUES
   ('ai_audio_evaluation', 'AI音频点评', '调用千问分析跟读记录生成评价', 'qwen-turbo', 0.05, 'active')
 ON CONFLICT (rule_code) DO UPDATE SET
   name_zh = excluded.name_zh,
   description_zh = excluded.description_zh,
   model = excluded.model,
   price_cny = excluded.price_cny,
   status = excluded.status;
