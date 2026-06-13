insert into public.pricing_rule (rule_code, name_zh, description_zh, model, price_cny, status)
values
  ('ai_conversation', 'AI 对话（创建会话）', '创建对话会话（返回 WS 参数与 instructions）', 'qwen3.5-omni-plus-realtime', 0.0000, 'active'),
  ('ai_conversation_question', 'AI 对话（提问）', '用户每次提问计费（一次 turn 的 user）', 'qwen3.5-omni-plus-realtime', 0.0100, 'active'),
  ('ai_conversation_answer', 'AI 对话（回答）', 'AI 每次回答计费（一次 turn 的 assistant）', 'qwen3.5-omni-plus-realtime', 0.0100, 'active'),
  ('ai_conversation_settle', 'AI 对话（结算）', '会话结束结算（记录轮次与时长）', 'qwen3.5-omni-plus-realtime', 0.0000, 'active')
on conflict (rule_code) do update set
  name_zh = excluded.name_zh,
  description_zh = excluded.description_zh,
  model = excluded.model,
  price_cny = excluded.price_cny,
  status = excluded.status;
