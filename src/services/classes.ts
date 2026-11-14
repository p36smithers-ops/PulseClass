import { supabase } from '../lib/supabase';

export type ClassRecord = {
  id: string;
  name: string;
  join_code: string;
  created_at: string;
};

export async function listTeacherClasses(): Promise<ClassRecord[]> {
  if (!supabase) throw new Error('Supabase is not configured yet.');
  const { data, error } = await supabase
    .from('classes')
    .select('id, name, join_code, created_at')
    .order('created_at', { ascending: false });
  if (error) throw error;
  return data ?? [];
}

export async function createTeacherClass(name: string): Promise<ClassRecord> {
  if (!supabase) throw new Error('Supabase is not configured yet.');
  const cleanName = name.trim();
  if (!cleanName) throw new Error('Enter a class name.');
  const { data, error } = await supabase.rpc('create_class', { p_name: cleanName });
  if (error) throw error;
  const createdId = typeof data === 'string' ? data : data?.id;
  if (!createdId) throw new Error('The class was created, but its ID was not returned.');
  const { data: record, error: readError } = await supabase
    .from('classes')
    .select('id, name, join_code, created_at')
    .eq('id', createdId)
    .single();
  if (readError) throw readError;
  return record;
}
