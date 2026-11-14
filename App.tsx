import React, { useEffect, useMemo, useState } from 'react';
import {
  SafeAreaView, ScrollView, StatusBar, StyleSheet, Text, TextInput,
  TouchableOpacity, View, Platform, ActivityIndicator
} from 'react-native';
import { supabase, isSupabaseConfigured } from './src/lib/supabase';
import { signInTeacher, signOutTeacher } from './src/services/teacherAuth';
import { createTeacherClass, listTeacherClasses, type ClassRecord } from './src/services/classes';

type Screen = 'home' | 'classes' | 'monitor' | 'join';

const palette = {
  ink: '#14251F', muted: '#718078', green: '#176B50', mint: '#E8F4EE',
  canvas: '#F5F7F4', white: '#FFFFFF', line: '#E5EBE6',
  amber: '#F3B64B', red: '#D9685B', blue: '#477DAB'
};

function Pill({ children, tone = 'green' }: { children: React.ReactNode; tone?: 'green' | 'amber' | 'blue' }) {
  const backgroundColor = tone === 'green' ? palette.mint : tone === 'amber' ? '#FFF4DD' : '#EAF1F8';
  const color = tone === 'green' ? palette.green : tone === 'amber' ? '#95620B' : palette.blue;
  return <View style={[styles.pill, { backgroundColor }]}><Text style={[styles.pillText, { color }]}>{children}</Text></View>;
}

function Metric({ label, value, note }: { label: string; value: string; note: string }) {
  return <View style={styles.metric}><Text style={styles.metricLabel}>{label}</Text><Text style={styles.metricValue}>{value}</Text><Text style={styles.metricNote}>{note}</Text></View>;
}

export default function App() {
  const [screen, setScreen] = useState<Screen>('home');
  const [teacherReady, setTeacherReady] = useState(false);
  const [authLoading, setAuthLoading] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [className, setClassName] = useState('');
  const [studentName, setStudentName] = useState('');
  const [joinCode, setJoinCode] = useState('');
  const [notice, setNotice] = useState('');
  const [classes, setClasses] = useState<ClassRecord[]>([]);

  async function refreshClasses() {
    try {
      const rows = await listTeacherClasses();
      setClasses(rows);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : 'Could not load your classes.');
    }
  }

  useEffect(() => {
    if (!supabase) { setAuthLoading(false); return; }
    let alive = true;
    supabase.auth.getSession().then(async ({ data }) => {
      if (!alive) return;
      const session = data.session;
      setTeacherReady(Boolean(session));
      if (session) await refreshClasses();
      if (alive) setAuthLoading(false);
    });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      setTeacherReady(Boolean(session));
      if (session) Promise.resolve().then(() => refreshClasses());
      else setClasses([]);
    });
    return () => { alive = false; listener.subscription.unsubscribe(); };
  }, []);

  async function handleSignIn() {
    setBusy(true); setNotice('');
    try {
      await signInTeacher(email, password);
      setPassword('');
      setTeacherReady(true);
      await refreshClasses();
    } catch (error) {
      setNotice(error instanceof Error ? error.message : 'Sign in failed.');
    } finally { setBusy(false); }
  }

  const activeClass = useMemo(() => classes[0], [classes]);

  async function addClass() {
    const name = className.trim();
    if (!name) { setNotice('Enter a class name first.'); return; }
    setBusy(true); setNotice('');
    try {
      await createTeacherClass(name);
      setClassName('');
      await refreshClasses();
      setNotice('Class saved successfully.');
    } catch (error) {
      setNotice(error instanceof Error ? error.message : 'Could not create class.');
    } finally { setBusy(false); }
  }

  function joinLesson() {
    if (!studentName.trim() || !joinCode.trim()) {
      setNotice('Enter your name and the class code to continue.');
      return;
    }
    setNotice('This is a preview only. Secure lesson joining will be enabled when the server connection is built.');
  }

  const navItems: { id: Screen; label: string; icon: string }[] = [
    { id: 'home', label: 'Home', icon: '⌂' },
    { id: 'classes', label: 'Classes', icon: '▦' },
    { id: 'monitor', label: 'Live lesson', icon: '♡' }
  ];

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar barStyle="dark-content" backgroundColor={palette.canvas} />
      <View style={styles.app}>
        <View style={styles.topbar}>
          <TouchableOpacity style={styles.brand} onPress={() => { setScreen('home'); setNotice(''); }}>
            <View style={styles.brandMark}><Text style={styles.brandMarkText}>P</Text></View>
            <View><Text style={styles.brandName}>PulseClass</Text><Text style={styles.brandSub}>TEACH • MOVE • LEARN</Text></View>
          </TouchableOpacity>
          {teacherReady && <TouchableOpacity style={styles.teacherAvatar} onPress={async () => { await signOutTeacher(); setTeacherReady(false); setNotice('Signed out.'); }}><Text style={styles.teacherAvatarText}>↗</Text></TouchableOpacity>}
        </View>

        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          {authLoading ? <View style={styles.authCard}><ActivityIndicator color={palette.green} /><Text style={styles.authHelp}>Checking your secure teacher session…</Text></View> : !isSupabaseConfigured ? <View style={styles.authCard}><Text style={styles.eyebrow}>SETUP REQUIRED</Text><Text style={styles.heading}>Connect PulseClass.</Text><Text style={styles.subheading}>The app screens are ready, but the Supabase project URL and publishable key still need to be added to the app environment before sign-in can work.</Text></View> : !teacherReady ? <View style={styles.authCard}><View style={styles.joinMark}><Text style={styles.joinMarkText}>♥</Text></View><Text style={styles.eyebrow}>TEACHER ACCESS</Text><Text style={styles.heading}>Welcome back.</Text><Text style={styles.subheading}>Sign in with your teacher account to manage classes and lessons.</Text><Text style={styles.fieldLabel}>EMAIL ADDRESS</Text><TextInput value={email} onChangeText={setEmail} placeholder="Teacher email" placeholderTextColor="#9AA69F" style={styles.input} autoCapitalize="none" keyboardType="email-address" /><Text style={styles.fieldLabel}>PASSWORD</Text><TextInput value={password} onChangeText={setPassword} placeholder="Password" placeholderTextColor="#9AA69F" style={styles.input} secureTextEntry /><TouchableOpacity style={styles.primaryButton} onPress={handleSignIn} disabled={busy}><Text style={styles.primaryButtonText}>{busy ? 'Signing in…' : 'Sign in securely  →'}</Text></TouchableOpacity><Text style={styles.privacyNote}>Student accounts are not needed. The teacher account is created separately in Supabase.</Text></View> : <>
          {screen === 'home' && <>
            <Text style={styles.eyebrow}>TEACHER WORKSPACE</Text>
            <Text style={styles.heading}>Good to see you.</Text>
            <Text style={styles.subheading}>Your classroom activity, all in one place.</Text>
            <View style={styles.hero}>
              <View style={{ flex: 1 }}>
                <Pill>YOUR TEACHING HUB</Pill>
                <Text style={styles.heroTitle}>Make every{ '\n' }heartbeat count.</Text>
                <Text style={styles.heroCopy}>Run engaging lessons and explore how your students respond to activity.</Text>
                <TouchableOpacity style={styles.heroButton} onPress={() => { setScreen('monitor'); setNotice(''); }}>
                  <Text style={styles.heroButtonText}>Start a lesson  →</Text>
                </TouchableOpacity>
              </View>
              <View style={styles.heartOrb}><Text style={styles.heartIcon}>♥</Text><Text style={styles.orbCaption}>LIVE</Text></View>
            </View>
            <View style={styles.sectionHeader}><Text style={styles.sectionTitle}>At a glance</Text><Text style={styles.sectionHint}>YOUR OVERVIEW</Text></View>
            <View style={styles.metricsRow}>
              <Metric label="CLASSES" value={String(classes.length)} note="Created" />
              <Metric label="STUDENTS" value="—" note="Not joined yet" />
              <Metric label="SESSIONS" value="0" note="This week" />
            </View>
            <View style={styles.sectionHeader}><Text style={styles.sectionTitle}>Your classes</Text><TouchableOpacity onPress={() => setScreen('classes')}><Text style={styles.link}>View all →</Text></TouchableOpacity></View>
            {classes.slice(0, 3).map((item, index) => <TouchableOpacity key={item.id} style={styles.classRow} onPress={() => { setScreen('monitor'); setNotice(''); }}>
              <View style={[styles.classIcon, { backgroundColor: index % 2 ? '#EEF1FA' : palette.mint }]}><Text style={styles.classIconText}>{index === 0 ? '⌬' : index === 1 ? '◉' : '▤'}</Text></View>
              <View style={{ flex: 1 }}><Text style={styles.className}>{item.name}</Text><Text style={styles.classMeta}>Join code {item.join_code}</Text></View>
              <Text style={styles.chevron}>›</Text>
            </TouchableOpacity>)}
            <TouchableOpacity style={styles.studentEntry} onPress={() => { setScreen('join'); setNotice(''); }}>
              <Text style={styles.studentEntryTitle}>Student joining preview</Text>
              <Text style={styles.studentEntryCopy}>Open the simple name + class-code experience →</Text>
            </TouchableOpacity>
          </>}

          {screen === 'classes' && <>
            <Text style={styles.eyebrow}>ORGANISE YOUR TEACHING</Text><Text style={styles.heading}>Your classes</Text>
            <Text style={styles.subheading}>Create groups and give students a simple way to join a lesson.</Text>
            <View style={styles.panel}>
              <Text style={styles.panelTitle}>Create a class</Text>
              <TextInput value={className} onChangeText={setClassName} placeholder="e.g. Year 11 Sports Science" placeholderTextColor="#9AA69F" style={styles.input} />
              <TouchableOpacity style={styles.primaryButton} onPress={addClass}><Text style={styles.primaryButtonText}>＋  Add class</Text></TouchableOpacity>
            </View>
            <View style={styles.sectionHeader}><Text style={styles.sectionTitle}>All classes</Text><Pill>{classes.length} groups</Pill></View>
            {classes.map(item => <View key={item.id} style={styles.classCard}>
              <View style={styles.classCardTop}><View style={styles.classIcon}><Text style={styles.classIconText}>▦</Text></View><Pill>Created</Pill></View>
              <Text style={styles.className}>{item.name}</Text><Text style={styles.classMeta}>Class join code</Text>
              <View style={styles.codeBox}><Text style={styles.codeText}>{item.join_code}</Text></View>
            </View>)}
          </>}

          {screen === 'monitor' && <>
            <Text style={styles.eyebrow}>CLASSROOM • SESSION</Text><Text style={styles.heading}>Live lesson</Text>
            <Text style={styles.subheading}>A clear view of class activity while your lesson is running.</Text>
            <View style={styles.livePanel}>
              <View style={styles.liveTop}><Pill tone="amber">NOT STARTED</Pill><Text style={styles.liveDate}>SESSION PREVIEW</Text></View>
              <Text style={styles.liveTitle}>{activeClass?.name ?? 'Choose a class'}</Text>
              <Text style={styles.liveDescription}>Your live class view will appear here once a session is connected.</Text>
              <View style={styles.liveStats}><View><Text style={styles.liveNumber}>—</Text><Text style={styles.liveLabel}>AVG. HEART RATE</Text></View><View><Text style={styles.liveNumber}>0</Text><Text style={styles.liveLabel}>CONNECTED</Text></View><View><Text style={styles.liveNumber}>—</Text><Text style={styles.liveLabel}>DURATION</Text></View></View>
              <TouchableOpacity style={styles.primaryButton} onPress={() => setNotice('Session controls will be connected after the secure database and student-join flow are implemented.')}><Text style={styles.primaryButtonText}>Start session (coming next)</Text></TouchableOpacity>
            </View>
            <View style={styles.infoCard}><Text style={styles.infoTitle}>Heart-rate monitoring</Text><Text style={styles.infoCopy}>The next build stage will connect validated student readings, class averages and live updates. No readings are being collected in this preview.</Text></View>
          </>}

          {screen === 'join' && <>
            <Text style={styles.eyebrow}>STUDENT ACCESS</Text><Text style={styles.heading}>Join your lesson.</Text>
            <Text style={styles.subheading}>Enter the name your teacher knows you by and the class code they shared.</Text>
            <View style={styles.joinCard}>
              <View style={styles.joinMark}><Text style={styles.joinMarkText}>♥</Text></View>
              <Text style={styles.panelTitle}>Welcome to PulseClass</Text>
              <Text style={styles.fieldLabel}>YOUR NAME</Text>
              <TextInput value={studentName} onChangeText={setStudentName} placeholder="Enter your name" placeholderTextColor="#9AA69F" style={styles.input} autoCapitalize="words" />
              <Text style={styles.fieldLabel}>CLASS CODE</Text>
              <TextInput value={joinCode} onChangeText={setJoinCode} placeholder="e.g. BIO10A" placeholderTextColor="#9AA69F" style={styles.input} autoCapitalize="characters" />
              <TouchableOpacity style={styles.primaryButton} onPress={joinLesson}><Text style={styles.primaryButtonText}>Join lesson  →</Text></TouchableOpacity>
              <Text style={styles.privacyNote}>No student password required. Secure, temporary lesson access will be added in the next stage.</Text>
            </View>
          </>}

          {!!notice && <View style={styles.notice}><Text style={styles.noticeText}>{notice}</Text></View>}
          <Text style={styles.footer}>PULSECLASS  •  EARLY BUILD  •  YOUR DATA STAYS YOURS</Text>
          </>}
        </ScrollView>

        {teacherReady && <View style={styles.tabbar}>
          {navItems.map(item => <TouchableOpacity key={item.id} onPress={() => { setScreen(item.id); setNotice(''); }} style={styles.tab}>
            <Text style={[styles.tabIcon, screen === item.id && styles.tabActive]}>{item.icon}</Text>
            <Text style={[styles.tabLabel, screen === item.id && styles.tabActive]}>{item.label}</Text>
          </TouchableOpacity>)}
          <TouchableOpacity onPress={() => { setScreen('join'); setNotice(''); }} style={styles.tab}>
            <Text style={[styles.tabIcon, screen === 'join' && styles.tabActive]}>＋</Text><Text style={[styles.tabLabel, screen === 'join' && styles.tabActive]}>Join</Text>
          </TouchableOpacity>
        </View>}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: palette.canvas, paddingTop: Platform.OS === 'android' ? 0 : 0 },
  app: { flex: 1, width: '100%', maxWidth: 760, alignSelf: 'center', backgroundColor: palette.canvas },
  topbar: { height: 72, paddingHorizontal: 22, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: palette.white, borderBottomWidth: 1, borderBottomColor: palette.line },
  brand: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  brandMark: { width: 38, height: 38, borderRadius: 13, backgroundColor: palette.green, alignItems: 'center', justifyContent: 'center' },
  brandMarkText: { color: palette.white, fontSize: 22, fontWeight: '800' },
  brandName: { color: palette.ink, fontWeight: '800', fontSize: 17, letterSpacing: -0.4 },
  brandSub: { color: palette.muted, fontSize: 8, letterSpacing: 1.5, marginTop: 2, fontWeight: '700' },
  teacherAvatar: { width: 36, height: 36, borderRadius: 18, backgroundColor: '#E8EEE9', alignItems: 'center', justifyContent: 'center' },
  teacherAvatarText: { color: palette.green, fontWeight: '800' },
  content: { padding: 22, paddingBottom: 34 },
  eyebrow: { color: palette.green, fontSize: 10, fontWeight: '800', letterSpacing: 1.7, marginTop: 8, marginBottom: 9 },
  heading: { color: palette.ink, fontSize: 31, fontWeight: '800', letterSpacing: -1.1 },
  subheading: { color: palette.muted, fontSize: 14, lineHeight: 21, marginTop: 7, marginBottom: 22, maxWidth: 520 },
  hero: { backgroundColor: '#153F32', borderRadius: 23, padding: 22, flexDirection: 'row', overflow: 'hidden', minHeight: 230 },
  pill: { alignSelf: 'flex-start', paddingHorizontal: 10, paddingVertical: 6, borderRadius: 20 },
  pillText: { fontSize: 9, fontWeight: '800', letterSpacing: 0.8 },
  heroTitle: { color: palette.white, fontSize: 30, fontWeight: '800', lineHeight: 33, letterSpacing: -0.7, marginTop: 16 },
  heroCopy: { color: '#D1E4D9', fontSize: 12, lineHeight: 18, maxWidth: 245, marginTop: 10 },
  heroButton: { backgroundColor: '#D8F0E1', alignSelf: 'flex-start', paddingHorizontal: 14, paddingVertical: 11, borderRadius: 12, marginTop: 17 },
  heroButtonText: { color: '#174B39', fontWeight: '800', fontSize: 12 },
  heartOrb: { width: 98, height: 98, borderRadius: 49, backgroundColor: '#2B6651', alignItems: 'center', justifyContent: 'center', alignSelf: 'center', marginLeft: 5 },
  heartIcon: { color: '#F6C7B9', fontSize: 40, lineHeight: 46 },
  orbCaption: { color: '#D5E9DE', fontSize: 8, fontWeight: '800', letterSpacing: 2 },
  sectionHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: 26, marginBottom: 13 },
  sectionTitle: { color: palette.ink, fontSize: 17, fontWeight: '800', letterSpacing: -0.3 },
  sectionHint: { color: '#9AA69F', fontSize: 9, fontWeight: '800', letterSpacing: 1 },
  link: { color: palette.green, fontSize: 12, fontWeight: '800' },
  metricsRow: { flexDirection: 'row', gap: 9 },
  metric: { flex: 1, backgroundColor: palette.white, borderRadius: 16, padding: 13, borderWidth: 1, borderColor: palette.line },
  metricLabel: { color: palette.muted, fontSize: 8, fontWeight: '800', letterSpacing: 0.7 },
  metricValue: { color: palette.ink, fontSize: 25, fontWeight: '800', marginTop: 7 },
  metricNote: { color: '#9AA69F', fontSize: 9, marginTop: 2 },
  classRow: { backgroundColor: palette.white, borderRadius: 15, padding: 12, marginBottom: 9, flexDirection: 'row', alignItems: 'center', gap: 12, borderWidth: 1, borderColor: palette.line },
  classIcon: { width: 42, height: 42, borderRadius: 13, backgroundColor: palette.mint, alignItems: 'center', justifyContent: 'center' },
  classIconText: { color: palette.green, fontSize: 20, fontWeight: '700' },
  className: { color: palette.ink, fontSize: 13, fontWeight: '800' },
  classMeta: { color: palette.muted, fontSize: 10, marginTop: 4 },
  chevron: { color: '#9AA69F', fontSize: 25 },
  studentEntry: { backgroundColor: '#EDF3F0', borderRadius: 16, padding: 16, marginTop: 14 },
  studentEntryTitle: { color: palette.ink, fontSize: 13, fontWeight: '800' },
  studentEntryCopy: { color: palette.green, fontSize: 11, marginTop: 6, fontWeight: '600' },
  panel: { backgroundColor: palette.white, borderRadius: 18, padding: 17, borderWidth: 1, borderColor: palette.line, marginBottom: 20 },
  panelTitle: { color: palette.ink, fontSize: 16, fontWeight: '800', marginBottom: 13 },
  input: { height: 48, borderWidth: 1, borderColor: palette.line, borderRadius: 12, paddingHorizontal: 13, color: palette.ink, backgroundColor: '#FBFCFB', fontSize: 13, marginBottom: 12 },
  primaryButton: { minHeight: 47, borderRadius: 12, backgroundColor: palette.green, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 15 },
  primaryButtonText: { color: palette.white, fontSize: 13, fontWeight: '800' },
  classCard: { backgroundColor: palette.white, borderRadius: 17, borderWidth: 1, borderColor: palette.line, padding: 15, marginBottom: 11 },
  classCardTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 13 },
  codeBox: { backgroundColor: palette.canvas, borderRadius: 10, padding: 11, marginTop: 7, alignItems: 'center' },
  codeText: { color: palette.green, fontSize: 17, fontWeight: '900', letterSpacing: 2.5 },
  livePanel: { backgroundColor: palette.white, borderRadius: 20, borderWidth: 1, borderColor: palette.line, padding: 18 },
  liveTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  liveDate: { color: '#9AA69F', fontSize: 9, fontWeight: '800', letterSpacing: 1 },
  liveTitle: { color: palette.ink, fontSize: 21, fontWeight: '800', marginTop: 18 },
  liveDescription: { color: palette.muted, fontSize: 12, lineHeight: 18, marginTop: 7 },
  liveStats: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 22, marginVertical: 17, borderTopWidth: 1, borderBottomWidth: 1, borderColor: palette.line },
  liveNumber: { color: palette.ink, fontSize: 26, fontWeight: '800', textAlign: 'center' },
  liveLabel: { color: palette.muted, fontSize: 8, fontWeight: '800', letterSpacing: 0.5, marginTop: 4 },
  infoCard: { backgroundColor: '#EAF2ED', borderRadius: 16, padding: 16, marginTop: 15 },
  infoTitle: { color: palette.green, fontSize: 13, fontWeight: '800' },
  infoCopy: { color: '#527064', fontSize: 11, lineHeight: 17, marginTop: 6 },
  joinCard: { backgroundColor: palette.white, borderRadius: 20, borderWidth: 1, borderColor: palette.line, padding: 20 },
  authCard: { backgroundColor: palette.white, borderRadius: 22, borderWidth: 1, borderColor: palette.line, padding: 22, marginTop: 20 },
  authHelp: { color: palette.muted, fontSize: 12, textAlign: 'center', marginTop: 12 },
  joinMark: { width: 48, height: 48, borderRadius: 16, backgroundColor: palette.mint, alignItems: 'center', justifyContent: 'center', marginBottom: 16 },
  joinMarkText: { color: palette.green, fontSize: 25 },
  fieldLabel: { color: palette.muted, fontSize: 9, fontWeight: '800', letterSpacing: 1, marginBottom: 7, marginTop: 5 },
  privacyNote: { color: '#87948C', fontSize: 10, lineHeight: 15, textAlign: 'center', marginTop: 14 },
  notice: { backgroundColor: '#FFF4DD', borderRadius: 12, padding: 12, marginTop: 16 },
  noticeText: { color: '#80590E', fontSize: 11, lineHeight: 17 },
  footer: { textAlign: 'center', color: '#A0AAA4', fontSize: 8, fontWeight: '700', letterSpacing: 1, marginTop: 27, marginBottom: 8 },
  tabbar: { height: 66, backgroundColor: palette.white, borderTopWidth: 1, borderTopColor: palette.line, flexDirection: 'row', justifyContent: 'space-around', alignItems: 'center', paddingBottom: Platform.OS === 'ios' ? 6 : 0 },
  tab: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 3 },
  tabIcon: { color: '#98A59D', fontSize: 18, fontWeight: '700' },
  tabLabel: { color: '#98A59D', fontSize: 9, fontWeight: '700' },
  tabActive: { color: palette.green }
});
