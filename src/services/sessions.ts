import { supabase } from '../lib/supabase';

export type LessonSession = {
  id: string;
  class_id: string;
  started_at: string;
  ended_at: string | null;
};

export async function startLessonSession(classId: string): Promise<LessonSession> {
  if (!supabase) throw new Error('Supabase is not configured yet.');
  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError) throw authError;
  if (!authData.user) throw new Error('Please sign in again.');

  const { data, error } = await supabase
    .from('sessions')
    .insert({
      class_id: classId,
      created_by: authData.user.id,
      started_at: new Date().toISOString(),
    })
    .select('id, class_id, started_at, ended_at')
    .single();
  if (error) throw error;
  return data;
}

export async function endLessonSession(sessionId: string): Promise<void> {
  if (!supabase) throw new Error('Supabase is not configured yet.');
  const { error } = await supabase
    .from('sessions')
    .update({ ended_at: new Date().toISOString() })
    .eq('id', sessionId)
    .is('ended_at', null);
  if (error) throw error;
}

export async function getActiveLessonSession(classId: string): Promise<LessonSession | null> {
  if (!supabase) throw new Error('Supabase is not configured yet.');
  const { data, error } = await supabase
    .from('sessions')
    .select('id, class_id, started_at, ended_at')
    .eq('class_id', classId)
    .is('ended_at', null)
    .order('started_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data;
}
