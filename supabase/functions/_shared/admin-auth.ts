import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

export async function verifyAdmin(token: string): Promise<{ user: any; role: string } | null> {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);
  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) return null;

  const { data: roleData } = await supabase
    .from('user_roles')
    .select('role')
    .eq('user_id', user.id)
    .single();

  if (!roleData || !['admin', 'moderator'].includes(roleData.role)) {
    return null;
  }

  return { user, role: roleData.role };
}
