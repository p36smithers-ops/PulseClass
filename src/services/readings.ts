import { supabase } from '../lib/supabase';

export type HeartRateReading = {
  id: number;
  bpm: number;
  user_id: string;
  recorded_at: string;
};

export async function listSessionReadings(sessionId: string): Promise<HeartRateReading[]> {
  if (!supabase) throw new Error('Supabase is not configured yet.');
  const { data, error } = await supabase
    .from('heart_rate_readings')
    .select('id, bpm, user_id, recorded_at')
    .eq('session_id', sessionId)
    .order('recorded_at', { ascending: false })
    .limit(500);
  if (error) throw error;
  return data ?? [];
}

export function subscribeToSessionReadings(
  sessionId: string,
  onReading: (reading: HeartRateReading) => void,
) {
  if (!supabase) throw new Error('Supabase is not configured yet.');
  return supabase
    .channel(`session-readings-${sessionId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'heart_rate_readings',
        filter: `session_id=eq.${sessionId}`,
      },
      (payload) => onReading(payload.new as HeartRateReading),
    )
    .subscribe();
}

export async function removeReadingsSubscription(channel: ReturnType<typeof subscribeToSessionReadings>) {
  if (!supabase) return;
  await supabase.removeChannel(channel);
}
