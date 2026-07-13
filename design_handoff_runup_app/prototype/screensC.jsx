/* ═══ RUNUP 4.0 — screens C : Détail séance · Profil/Réglages · Historique ═══ */

/* ---------- SESSION DETAIL (sheet) ---------- */
function SessionDetailSheet({onClose}){
  const c=React.useContext(Ctx), s=c.store, sess=s.session;
  const [moved,setMoved]=useState(false);
  const steps=[
    ['Échauffement','15′ · Z2 · footing relâché',CYAN],
    [`${sess.title.match(/\d+/)?.[0]||6} × 800 m`,`${sess.pace} /km · ${sess.zone} · récup 400 m entre chaque`,R],
    ['Retour au calme','10′ · Z1 · marche + étirements',LIME]
  ];
  return (
    <div className="sheet-wrap">
      <div className="sheet-bg" onClick={onClose}></div>
      <div className="sheet">
        <div className="handle"></div>
        <div className="pad" style={{padding:'8px 18px 24px'}}>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start',marginTop:8}}>
            <div>
              <div className="eye" style={{color:R}}>{s.day} · séance clé</div>
              <div className="b" style={{fontSize:26,marginTop:4}}>{sess.title}</div>
            </div>
            {sess.adj && <span className="chip" style={{background:'rgba(255,15,91,.14)',color:R2}}>{sess.adj}</span>}
          </div>
          <div style={{display:'flex',gap:16,marginTop:16}}>
            <div className="metric"><span className="v">{sess.dur}′</span><span className="l">Durée</span></div>
            <div className="metric"><span className="v">{sess.pace}</span><span className="l">Allure cible</span></div>
            <div className="metric"><span className="v" style={{color:R2}}>{sess.zone}</span><span className="l">Zone</span></div>
          </div>

          <div className="eye" style={{color:'var(--t3)',margin:'22px 2px 10px'}}>Structure de la séance</div>
          <div style={{display:'flex',flexDirection:'column',gap:6}}>
            {steps.map(([t,d,col],i)=>(
              <div key={i} style={{display:'flex',alignItems:'center',gap:12,background:'var(--card2)',border:'.5px solid var(--line)',borderRadius:14,padding:'12px 14px'}}>
                <div style={{width:3,height:32,borderRadius:2,background:col,flexShrink:0}}></div>
                <div style={{flex:1}}><div style={{fontSize:13,fontWeight:600}}>{t}</div><div style={{fontSize:11,color:'var(--t2)',marginTop:2}}>{d}</div></div>
              </div>))}
          </div>

          <div style={{marginTop:16,background:'rgba(255,255,255,.045)',border:'.5px solid var(--line)',borderRadius:16,padding:'13px 14px',fontSize:12,color:'var(--t2)',lineHeight:1.5}}>
            💡 Ta forme est excellente aujourd'hui — le coach a déjà relevé cette séance d'un palier.
          </div>

          {moved ? (
            <div style={{marginTop:16,textAlign:'center',padding:16,background:'rgba(200,255,61,.08)',border:'.5px solid rgba(200,255,61,.25)',borderRadius:16,color:LIME,fontSize:13,fontWeight:600}}>
              Séance déplacée à demain ✓
            </div>
          ) : (
            <div style={{display:'flex',gap:8,marginTop:16}}>
              <button className="press" onClick={()=>{setMoved(true);toast('Séance déplacée à demain');}} style={{flex:1,padding:14,borderRadius:14,background:'var(--card2)',border:'.5px solid var(--line)',color:'#fff',fontSize:13,fontWeight:600}}>Déplacer à demain</button>
              <button className="b btn-rose press" style={{flex:1.4,padding:14}} onClick={()=>{onClose();c.startRun();}}>▶ DÉMARRER</button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

/* ---------- PROFIL & RÉGLAGES ---------- */
function ProfileScreen(){
  const c=React.useContext(Ctx), s=c.store;
  const [services,setServices]=useState({apple:true,strava:true,garmin:false});
  const [unit,setUnit]=useState('km');
  const [notifs,setNotifs]=useState(true);
  const toggle=(k)=>setServices(v=>({...v,[k]:!v[k]}));

  const Row=({children})=><div style={{display:'flex',alignItems:'center',gap:12,padding:'13px 14px',borderBottom:'.5px solid var(--line)'}}>{children}</div>;
  const Switch=({on,onClick})=>(
    <button className="press" onClick={onClick} style={{width:42,height:25,borderRadius:99,background:on?R:'rgba(255,255,255,.15)',position:'relative',flexShrink:0}}>
      <span style={{position:'absolute',top:2,left:on?19:2,width:21,height:21,borderRadius:'50%',background:'#fff',transition:'left .2s'}}></span>
    </button>
  );

  return (
    <div className="scan fade" style={{paddingBottom:120}}>
      <div className="pad" style={{paddingTop:8}}>
        <div style={{display:'flex',alignItems:'center',gap:12,margin:'2px 0 18px'}}>
          <button className="press" onClick={()=>c.go('prog')} style={{fontSize:22,color:'var(--t2)'}}>‹</button>
          <div className="b" style={{fontSize:22}}>Profil &amp; réglages</div>
        </div>

        <div style={{display:'flex',alignItems:'center',gap:14,marginBottom:16}}>
          <div style={{width:60,height:60,borderRadius:'50%',background:`linear-gradient(135deg,${R},${VIO})`,display:'flex',alignItems:'center',justifyContent:'center'}}><span className="b" style={{fontSize:24}}>{s.name[0]}</span></div>
          <div><div className="b" style={{fontSize:20}}>{s.name}</div><div style={{fontSize:12,color:'var(--t2)',marginTop:2}}>Objectif · {s.goal}</div></div>
        </div>

        <button className="press" onClick={s.premium?undefined:c.openPaywall} style={{width:'100%',display:'flex',alignItems:'center',gap:12,textAlign:'left',padding:'14px 16px',borderRadius:18,marginBottom:20,
          background:s.premium?'rgba(200,255,61,.08)':'linear-gradient(135deg,rgba(124,92,255,.16),rgba(255,15,91,.12))',border:`.5px solid ${s.premium?'rgba(200,255,61,.3)':'rgba(124,92,255,.35)'}`}}>
          <div style={{width:34,height:34,borderRadius:10,background:s.premium?'rgba(200,255,61,.15)':'rgba(124,92,255,.2)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={s.premium?LIME:VIO} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 2l2.5 6.5L21 9l-5 4.5L17.5 21 12 17l-5.5 4L8 13.5 3 9l6.5-.5z"/></svg>
          </div>
          <div style={{flex:1}}>
            <div style={{fontSize:14,fontWeight:700}}>{s.premium?'Runner Premium':'Passer à Premium'}</div>
            <div style={{fontSize:11,color:'var(--t2)',marginTop:2}}>{s.premium?'Coach illimité, stats avancées, connexions étendues':'Coach illimité, prédictions de course, plus encore'}</div>
          </div>
          {!s.premium && <span style={{color:VIO,fontSize:16}}>→</span>}
        </button>

        <div className="eye" style={{color:'var(--t3)',margin:'6px 2px 10px'}}>Sources de données</div>
        <div className="card" style={{borderRadius:16,overflow:'hidden'}}>
          {[['apple','🍎','Apple Santé'],['strava','🟠','Strava'],['garmin','⌚','Garmin Connect']].map(([id,e,n],i)=>(
            <Row key={id}>
              <span style={{fontSize:17}}>{e}</span>
              <span style={{flex:1,fontSize:14,fontWeight:500}}>{n}</span>
              <Switch on={services[id]} onClick={()=>toggle(id)}/>
            </Row>))}
        </div>

        <div className="eye" style={{color:'var(--t3)',margin:'20px 2px 10px'}}>Préférences</div>
        <div className="card" style={{borderRadius:16,overflow:'hidden'}}>
          <Row>
            <span style={{flex:1,fontSize:14,fontWeight:500}}>Unité de distance</span>
            <div style={{display:'flex',gap:4,background:'rgba(255,255,255,.06)',borderRadius:99,padding:3}}>
              {['km','mi'].map(u=>(
                <button key={u} className="press" onClick={()=>setUnit(u)} style={{padding:'6px 14px',borderRadius:99,background:unit===u?R:'none',color:'#fff',fontSize:12,fontWeight:600}}>{u}</button>))}
            </div>
          </Row>
          <Row>
            <span style={{flex:1,fontSize:14,fontWeight:500}}>Notifications du coach</span>
            <Switch on={notifs} onClick={()=>setNotifs(v=>!v)}/>
          </Row>
        </div>

        <div className="eye" style={{color:'var(--t3)',margin:'20px 2px 10px'}}>Programme</div>
        <div className="card" style={{borderRadius:16,overflow:'hidden'}}>
          <button className="press" onClick={()=>c.go('race')} style={{width:'100%',display:'flex',alignItems:'center',padding:'13px 14px',borderBottom:'.5px solid var(--line)'}}>
            <span style={{flex:1,fontSize:14,fontWeight:500,textAlign:'left'}}>Voir mon objectif</span><span style={{color:'var(--t2)'}}>›</span>
          </button>
          <button className="press" onClick={()=>c.openProgramSettings()} style={{width:'100%',display:'flex',alignItems:'center',padding:'13px 14px',borderBottom:'.5px solid var(--line)'}}>
            <span style={{flex:1,fontSize:14,fontWeight:500,textAlign:'left'}}>Modifier jours &amp; objectif</span><span style={{color:'var(--t2)'}}>›</span>
          </button>
          <button className="press" onClick={c.replayOb} style={{width:'100%',display:'flex',alignItems:'center',padding:'13px 14px'}}>
            <span style={{flex:1,fontSize:14,fontWeight:500,textAlign:'left'}}>Refaire l'onboarding</span><span style={{color:'var(--t2)'}}>›</span>
          </button>
        </div>

        {s.programPhase==='active' && (
          <button className="press" onClick={c.endProgram} style={{width:'100%',marginTop:20,padding:'12px 14px',borderRadius:14,background:'rgba(255,255,255,.03)',border:'.5px dashed var(--line)',color:'var(--t3)',fontSize:11.5,fontWeight:600}}>
            Terminer le programme (démo)
          </button>
        )}
        <button className="press" onClick={c.toggleCoachOffline} style={{width:'100%',marginTop:8,padding:'12px 14px',borderRadius:14,background:'rgba(255,255,255,.03)',border:'.5px dashed var(--line)',color:'var(--t3)',fontSize:11.5,fontWeight:600}}>
          {s.coachOffline?'Reconnecter le coach (démo)':'Simuler coach hors ligne (démo)'}
        </button>
      </div>
    </div>
  );
}

/* ---------- HISTORIQUE ---------- */
const HISTORY_SEED=[
  {d:'Mar 9 juil.',title:'Fractionné 6 × 800 m',dist:7.2,t:1842,pace:'4:16',hr:157},
  {d:'Dim 7 juil.',title:'Sortie longue',dist:12.4,t:4380,pace:'5:53',hr:148},
  {d:'Ven 5 juil.',title:'Récup active',dist:5.0,t:1800,pace:'6:00',hr:132},
  {d:'Mer 3 juil.',title:'Fractionné 5 × 1000 m',dist:8.1,t:2160,pace:'4:26',hr:161},
  {d:'Lun 1 juil.',title:'Footing',dist:6.5,t:2280,pace:'5:50',hr:139}
];

function HistoryScreen(){
  const c=React.useContext(Ctx), s=c.store;
  const runs=[...(s.history||[]),...HISTORY_SEED];
  return (
    <div className="scan fade" style={{paddingBottom:120}}>
      <div className="pad" style={{paddingTop:8}}>
        <div style={{display:'flex',alignItems:'center',gap:12,margin:'2px 0 16px'}}>
          <button className="press" onClick={()=>c.go('stats')} style={{fontSize:22,color:'var(--t2)'}}>‹</button>
          <div><div className="eye" style={{color:R}}>{runs.length} sorties</div><div className="b" style={{fontSize:22}}>Historique</div></div>
        </div>
        <div style={{display:'flex',flexDirection:'column',gap:8}}>
          {runs.map((r,i)=>(
            <div key={i} className="card" style={{padding:'14px 16px'}}>
              <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
                <div style={{fontSize:11,color:'var(--t2)'}}>{r.d}</div>
                <div style={{fontSize:11,color:'var(--t3)'}}>FC moy {r.hr}</div>
              </div>
              <div style={{fontSize:15,fontWeight:600,marginTop:4}}>{r.title}</div>
              <div style={{display:'flex',gap:20,marginTop:10}}>
                <div className="metric"><span className="v" style={{fontSize:20}}>{r.dist.toFixed(1)}</span><span className="l">km</span></div>
                <div className="metric"><span className="v" style={{fontSize:20}}>{fmt(r.t)}</span><span className="l">temps</span></div>
                <div className="metric"><span className="v" style={{fontSize:20,color:R2}}>{r.pace}</span><span className="l">allure moy</span></div>
              </div>
            </div>))}
        </div>
      </div>
    </div>
  );
}

Object.assign(window,{SessionDetailSheet,ProfileScreen,HistoryScreen,NotifsSheet,ProgramSettingsSheet});

/* ---------- NOTIFICATIONS ---------- */
function NotifsSheet({onClose}){
  const c=React.useContext(Ctx);
  const {notifs,markNotifsRead}=c;
  React.useEffect(()=>{markNotifsRead();},[]);
  return (
    <div className="sheet-wrap">
      <div className="sheet-bg" onClick={onClose}></div>
      <div className="sheet" style={{maxHeight:'80%'}}>
        <div className="handle"></div>
        <div className="pad" style={{padding:'8px 18px 28px'}}>
          <div className="b" style={{fontSize:22,marginTop:8,marginBottom:14}}>Notifications</div>
          <div style={{display:'flex',flexDirection:'column',gap:8}}>
            {notifs.map((n,i)=>(
              <div key={i} style={{display:'flex',gap:12,padding:'13px 14px',borderRadius:16,background:'var(--card2)',border:'.5px solid var(--line)'}}>
                <div style={{width:36,height:36,borderRadius:'50%',background:n.icon==='mark'?'none':(n.col||R),display:'flex',alignItems:'center',justifyContent:'center',fontSize:16,flexShrink:0}}>{n.icon==='mark'?<AppMark size={36}/>:n.icon}</div>
                <div style={{flex:1}}>
                  <div style={{fontSize:13,fontWeight:600}}>{n.title}</div>
                  <div style={{fontSize:12,color:'var(--t2)',marginTop:2,lineHeight:1.4}}>{n.text}</div>
                  <div style={{fontSize:10,color:'var(--t3)',marginTop:5}}>{n.time}</div>
                </div>
              </div>))}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------- PROGRAM SETTINGS (edit days & objectif) ---------- */
function ProgramSettingsSheet({onClose}){
  const c=React.useContext(Ctx), s=c.store;
  const [days,setDays]=useState(s.progDays||[0,1,3,5]);
  const [goal,setGoal]=useState(s.goal);
  const DAYS=['L','M','M','J','V','S','D'];
  return (
    <div className="sheet-wrap">
      <div className="sheet-bg" onClick={onClose}></div>
      <div className="sheet">
        <div className="handle"></div>
        <div className="pad" style={{padding:'8px 18px 26px'}}>
          <div className="b" style={{fontSize:22,marginTop:8}}>Modifier mon programme</div>
          <div className="eye" style={{color:'var(--t3)',margin:'20px 2px 10px'}}>Jours de course</div>
          <div style={{display:'flex',gap:7}}>
            {DAYS.map((d,i)=>{
              const on=days.includes(i);
              return <button key={i} className="press" onClick={()=>setDays(ds=>on?ds.filter(x=>x!==i):[...ds,i])}
                style={{flex:1,aspectRatio:'1',borderRadius:14,background:on?R:'var(--card)',border:`.5px solid ${on?R:'var(--line)'}`,display:'flex',alignItems:'center',justifyContent:'center'}}>
                <span className="b" style={{fontSize:15,color:on?'#fff':'var(--t2)'}}>{d}</span>
              </button>;})}
          </div>
          <div className="eye" style={{color:'var(--t3)',margin:'22px 2px 10px'}}>Objectif</div>
          <input value={goal} onChange={e=>setGoal(e.target.value)}
            style={{width:'100%',background:'var(--card)',border:'.5px solid var(--line)',borderRadius:14,padding:'13px 16px',color:'#fff',fontSize:14,fontFamily:'inherit',outline:'none'}}/>
          <div style={{marginTop:14,fontSize:11.5,color:'var(--t2)',lineHeight:1.5}}>Le coach recalcule tes prochaines séances dès l'enregistrement.</div>
          <button className="b btn-rose press" style={{marginTop:18}} disabled={days.length<2}
            onClick={()=>{c.updateProgram(days,goal);onClose();}}>ENREGISTRER</button>
        </div>
      </div>
    </div>
  );
}
