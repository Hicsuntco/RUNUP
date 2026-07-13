/* ═══ RUNUP 4.0 — App : state · nav · live sim · coach IA ═══ */
const {useState,useRef,useEffect}=React;

function toast(msg){
  const el=document.getElementById('toast');
  el.textContent=msg;el.classList.add('show');
  clearTimeout(el._t);el._t=setTimeout(()=>el.classList.remove('show'),2200);
}

const CUES=[
  [6,"C'est parti Léa. Échauffement tranquille, reste en Z2."],
  [120,"Fin d'échauffement. Premier 800 : vise 4:10, foulée relâchée."],
  [360,"Beau rythme, tu tiens 4:09 — FC bien maîtrisée 👊"],
  [720,"Mi-séance, tu gères parfaitement. Garde ta cadence."],
  [1080,"Dernier bloc, c'est le moment — lâche tout dessus 🔥"]
];

function App(){
  const [screen,setScreen]=useState('prog');
  const [onboarded,setOnboarded]=useState(()=>{try{return sessionStorage.getItem('runup4_ob_session')==='1';}catch(e){return false;}});
  const [store,setStore]=useState({
    name:'Léa', week_no:4, day:'Jeudi',
    readiness:84, streak:12, xp:310, raceIn:33, goal:'10 km · 47:30',
    ringsDone:2,
    rings:{move:{v:540,goal:650},active:{v:42,goal:60},run:{v:7.2,goal:10}},
    session:{title:'Fractionné 6 × 800 m',sub:'récup 400 m · échauffement 15′ inclus',dur:48,pace:'4:12',zone:'Z4',adj:'+1 palier'},
    week:[{d:'L',st:'done'},{d:'M',st:'done'},{d:'M',st:'done'},{d:'J',st:'today'},{d:'V',st:''},{d:'S',st:''},{d:'D',st:'rest'}],
    lastRun:null,
    history:[],
    progDays:[0,1,3,5],
    goalId:'race',
    programPhase:'active',
    recoveryDaysLeft:0,
    premium:false,
    coachOffline:false
  });

  /* ---- live run simulation ---- */
  const [live,setLive]=useState(null);
  const [runOn,setRunOn]=useState(false);
  const lr=useRef(null);
  const timer=useRef(null);

  function startRun(){
    lr.current={t:0,dist:0,kcal:0,interval:1,paused:false,coach:'',fired:new Set(),hr:150,gpsIssue:false,gpsFired:false};
    setLive({...lr.current,pace:'4:12'});
    setRunOn(true);
    setScreen('live');
    clearInterval(timer.current);
    timer.current=setInterval(()=>{
      const s=lr.current;
      if(s.paused){setLive(x=>({...x,paused:true}));return;}
      s.t+=6; s.dist+=0.026; s.kcal+=3;
      s.hr=156+Math.round(Math.sin(s.t/40)*6+Math.random()*3);
      s.interval=Math.min(6,1+Math.floor(s.dist/1.2));
      for(const [th,msg] of CUES){ if(s.t>=th && !s.fired.has(th)){s.fired.add(th);s.coach=msg;} }
      if(!s.gpsFired && s.t>=42){ s.gpsFired=true; s.gpsIssue=true; setTimeout(()=>{ if(lr.current){lr.current.gpsIssue=false; setLive(x=>x&&({...x,gpsIssue:false}));} },5000); }
      const pace='4:'+String(6+Math.floor(Math.abs(Math.sin(s.t/25))*10)).padStart(2,'0');
      setLive({...s,pace,fired:undefined});
    },820);
  }
  function togglePause(){ lr.current.paused=!lr.current.paused; setLive(x=>({...x,paused:lr.current.paused})); }
  function stopRun(){
    clearInterval(timer.current);
    setRunOn(false);
    const s=lr.current;
    const dist=Math.max(0.4,s.dist), t=Math.max(30,s.t);
    const secPerKm=t/dist;
    const avgPace=fmt(secPerKm);
    const nkm=Math.max(1,Math.floor(dist));
    const splits=Array.from({length:nkm},(_,i)=>{const sec=secPerKm-8+i*3+(i===nkm-1?-10:0);return fmt(Math.max(230,sec));});
    setStore(st=>({...st,lastRun:{title:st.session.title,dist,t,avgPace,avgHr:158,kcal:Math.round(s.kcal),splits}}));
    setScreen('recap');
  }
  function finishDebrief(rpe){
    setStore(st=>{
      const run=st.lastRun; const r=st.rings;
      const rings={
        move:{...r.move,v:Math.min(r.move.goal,r.move.v+run.kcal)},
        active:{...r.active,v:Math.min(r.active.goal,Math.round(r.active.v+run.t/60))},
        run:{...r.run,v:Math.min(r.run.goal,+(r.run.v+run.dist).toFixed(1))}
      };
      const done=Object.values(rings).filter(x=>x.v>=x.goal).length;
      const week=st.week.map(d=>d.st==='today'?{...d,st:'done'}:d);
      const historyEntry={d:"Aujourd'hui",title:run.title,dist:run.dist,t:run.t,pace:run.avgPace,hr:run.avgHr};
      return {...st,rings,ringsDone:done,streak:st.streak+1,xp:st.xp+120,week,history:[historyEntry,...(st.history||[])],
        session:{title:'Fractionné 7 × 800 m',sub:'progression · récup 400 m',dur:52,pace:'4:10',zone:'Z4',adj:'+1 palier'}};
    });
    toast('Programme mis à jour · +120 XP 🔥');
    setScreen('rings');
  }

  /* ---- coach IA ---- */
  const [chat,setChat]=useState([{role:'coach',text:"Salut Léa 👋 Ta forme est au top aujourd'hui (84/100). J'ai relevé ta séance à 6×800. Une question avant de te lancer ?"}]);
  const [coachTyping,setCoachTyping]=useState(false);
  const storeRef=useRef(store); useEffect(()=>{storeRef.current=store;},[store]);

  async function sendCoach(text){
    const next=[...chat,{role:'user',text}];
    setChat(next); setCoachTyping(true);
    const s=storeRef.current;
    if(s.coachOffline){
      setTimeout(()=>{
        setChat(c=>[...c,{role:'error',text:"Impossible de joindre ton coach — vérifie ta connexion et réessaie."}]);
        setCoachTyping(false);
      },900);
      return;
    }
    const extra=[
      s.weightNow&&s.weightTarget?`Poids actuel ${s.weightNow}kg, objectif ${s.weightTarget}kg (taille ${s.height||'?'}cm).`:'',
      s.focusArea?`Priorité de progression : ${s.focusArea}.${s.bestPerf?` Meilleure perf : ${s.bestPerf}.`:''}`:'',
      s.injury&&s.injury!=='none'?`Attention, zone sensible signalée : ${s.injury}.`:'',
      s.weeklyTime?`Dispo hebdo souhaitée : ${s.weeklyTime}, préfère courir le ${s.preferredTime||'?'}.`:'',
      s.age?`${s.age} ans.`:''
    ].filter(Boolean).join(' ');
    const sys=`Tu es le coach running personnel de ${s.name} dans l'app RUNUP. Tu n'es PAS un assistant ni une IA — tu es SON coach, tu la connais.
Profil : ${s.name}, coureuse intermédiaire, objectif ${s.goal}${s.raceDate?` le ${new Date(s.raceDate+'T09:00').toLocaleDateString('fr-FR',{day:'numeric',month:'long'})}`:''} (dans ${s.raceIn} jours). Programme de 9 semaines, actuellement semaine ${s.week_no} (bloc VMA). ${extra}
Aujourd'hui : forme ${s.readiness}/100 (excellente, bien récupérée). Séance du jour : ${s.session.title} (${s.session.dur} min, allure ${s.session.pace}, ${s.session.zone}). VO2max ~52.4 (en progrès). Série de ${s.streak} jours.
Style : français, tutoiement, chaleureux, motivant, TRÈS concret et bref (2-4 phrases max). Au plus un emoji occasionnel. Ne dis jamais que tu es une IA ou un modèle. Tu peux ajuster ses séances, donner des conseils d'allure, de récup, de nutrition, d'objectif.`;
    try{
      const reply=await window.claude.complete({
        system:sys,
        messages:next.map(m=>({role:m.role==='coach'?'assistant':'user',content:m.text})),
        max_tokens:400
      });
      setChat(c=>[...c,{role:'coach',text:(reply||'').trim()||"Je réfléchis… reformule pour moi ?"}]);
    }catch(e){
      setChat(c=>[...c,{role:'error',text:"Connexion coupée — le coach n'a pas pu répondre. Réessaie dans un instant."}]);
    }finally{ setCoachTyping(false); }
  }

  function finishOb(profile){
    const DL={'5k':'5 km','10k':'10 km','semi':'Semi','marathon':'Marathon'};
    const distLabel=profile.dist==='other'?(profile.customDist||'Ta course'):DL[profile.dist];
    setStore(st=>({...st,name:profile.name,age:profile.age,birthdate:profile.birthdate,goalId:profile.goal,
      raceIn:profile.goal==='race'&&profile.raceIn?profile.raceIn:st.raceIn,
      raceDate:profile.raceDate||null,
      weightNow:profile.weightNow||null,weightTarget:profile.weightTarget||null,height:profile.height||null,
      focusArea:profile.focusArea||null,bestPerf:profile.bestPerf||null,
      lastRan:profile.lastRan||null,injury:profile.injury||null,
      weeklyTime:profile.weeklyTime||null,preferredTime:profile.preferredTime||null,
      goal:profile.goal==='race'?`${distLabel} · ${(!profile.chrono||profile.chrono==='finir')?'finir':profile.chrono}`:profile.goal==='progress'?'Progresser':profile.goal==='restart'?'Reprise en douceur':profile.goal==='weight'?'Perte de poids':'Rester en forme'}));
    try{sessionStorage.setItem('runup4_ob_session','1');}catch(e){}
    setOnboarded(true); setScreen('prog');
    if(!store.premium) setShowPaywall(true);
    toast('Ton programme de 9 semaines est prêt');
  }
  function replayOb(){ try{sessionStorage.removeItem('runup4_ob_session');}catch(e){} setOnboarded(false); }
  const [sessionDetail,setSessionDetail]=useState(false);
  const [programSettings,setProgramSettings]=useState(false);
  const [showPaywall,setShowPaywall]=useState(false);
  function setPremium(v){ setStore(st=>({...st,premium:v})); }
  function toggleCoachOffline(){ setStore(st=>({...st,coachOffline:!st.coachOffline})); }

  /* ---- notifications ---- */
  const [notifs,setNotifs]=useState([
    {icon:'mark',col:R,title:'Séance ajustée',text:"Ta forme est excellente — on a relevé la séance du jour d'un palier.",time:'il y a 1 h',read:false},
    {icon:'🔥',col:VIO,title:'Série de 12 jours',text:'Tu tiens ta série — encore une sortie pour passer à 13.',time:'ce matin',read:false},
    {icon:'🏆',col:LIME,title:'Défi du mois',text:'Plus que 29 km pour boucler les 100 km de juillet.',time:'hier',read:true}
  ]);
  const unreadCount=notifs.filter(n=>!n.read).length;
  function markNotifsRead(){ setNotifs(ns=>ns.map(n=>({...n,read:true}))); }
  function updateProgram(days,goal){
    setStore(st=>({...st,progDays:days,goal}));
    toast('Programme mis à jour');
  }

  /* ---- fin de programme · récupération · nouvel objectif · course libre ---- */
  function endProgram(){
    setStore(st=>{
      const total=(window.RECOVERY_DAYS&&window.RECOVERY_DAYS[st.goalId])||4;
      return {...st,programPhase:'recovery',recoveryDaysLeft:total};
    });
    toast('Programme terminé — place à la récup');
  }
  function tickRecovery(){
    setStore(st=>{
      const left=st.recoveryDaysLeft-1;
      if(left<=0) return {...st,recoveryDaysLeft:0,programPhase:'choice'};
      return {...st,recoveryDaysLeft:left};
    });
  }
  function chooseFreeRun(){
    setStore(st=>{
      const t=(window.FREE_RUN_TEMPLATES&&window.FREE_RUN_TEMPLATES[0])||{title:'Footing',sub:'',dur:35,pace:'5:40',zone:'Z2'};
      return {...st,programPhase:'freerun',goal:'Course libre',goalId:'health',
        session:{...t,adj:null},freerunIdx:0};
    });
    toast('Mode course libre activé');
    setScreen('prog');
  }
  function startNewProgram(profile){
    const DL={'5k':'5 km','10k':'10 km','semi':'Semi','marathon':'Marathon'};
    setStore(st=>({...st,
      goalId:profile.goal,
      goal:profile.goal==='race'?`${DL[profile.dist]} · ${profile.chrono}`:profile.goal==='progress'?'Progresser':profile.goal==='weight'?'Perte de poids':'Rester en forme',
      progDays:profile.days,
      programPhase:'active',
      week_no:1,
      raceIn:profile.goal==='race'?63:st.raceIn,
      week:st.week.map((d,i)=>({...d,st:profile.days.includes(i)?(i===3?'today':''):'rest'})),
      session:{title:profile.goal==='race'?'Footing de reprise':'Séance de reprise',sub:'on repart en douceur sur de nouvelles bases',dur:30,pace:'5:30',zone:'Z2',adj:null}
    }));
    toast('Ton nouveau programme est prêt 🎉'.replace(' 🎉',''));
    setScreen('prog');
  }

  const go=(s)=>{ setScreen(s); };
  const ctx={screen,go,store,startRun,live,runOn,togglePause,stopRun,finishDebrief,chat,coachTyping,sendCoach,replayOb,
    openSessionDetail:()=>setSessionDetail(true),
    openProgramSettings:()=>setProgramSettings(true),
    notifs,unreadCount,markNotifsRead,openNotifs:()=>setNotifsOpen(true),updateProgram,
    endProgram,tickRecovery,chooseFreeRun,startNewProgram,
    setPremium,toggleCoachOffline,openPaywall:()=>setShowPaywall(true)};

  const [notifsOpen,setNotifsOpen]=useState(false);
  const SCREENS={prog:ProgScreen,plan:PlanScreen,rings:RingsScreen,live:LiveScreen,recap:RecapScreen,coach:CoachScreen,stats:StatsScreen,club:ClubScreen,race:RaceScreen,profile:ProfileScreen,history:HistoryScreen};
  const Cur=SCREENS[screen]||ProgScreen;
  const showBar=!['live','recap'].includes(screen);

  if(!onboarded) return (
    <Ctx.Provider value={ctx}>
      <Onboarding onDone={finishOb}/>
    </Ctx.Provider>
  );

  if(showPaywall) return (
    <Ctx.Provider value={ctx}>
      <PaywallScreen onSkip={()=>setShowPaywall(false)}/>
    </Ctx.Provider>
  );

  return (
    <Ctx.Provider value={ctx}>
      <StatusBar/>
      <Cur/>
      {sessionDetail && <SessionDetailSheet onClose={()=>setSessionDetail(false)}/>}
      {programSettings && <ProgramSettingsSheet onClose={()=>setProgramSettings(false)}/>}
      {notifsOpen && <NotifsSheet onClose={()=>setNotifsOpen(false)}/>}
      {showBar && runOn && screen!=='live' && (
        <button className="press rise" onClick={()=>go('live')} style={{position:'absolute',bottom:92,left:'50%',transform:'translateX(-50%)',zIndex:45,display:'flex',alignItems:'center',gap:8,padding:'9px 16px',borderRadius:99,background:R,color:'#fff',boxShadow:'0 10px 28px rgba(255,15,91,.5)'}}>
          <span className="pulse" style={{width:7,height:7,borderRadius:'50%',background:'#fff'}}></span>
          <span className="b" style={{fontSize:12,letterSpacing:1}}>RUN EN COURS · {live?fmt(live.t):''}</span>
        </button>
      )}
      {showBar && <TabBar/>}
    </Ctx.Provider>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
