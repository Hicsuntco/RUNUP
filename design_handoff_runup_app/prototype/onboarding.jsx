/* ═══ RUNUP 4.0 — Onboarding : comprendre l'objectif ═══ */

const OB_GOALS=[
  ['race','Préparer une course','Un dossard en vue — on construit le plan pour le jour J','🏁'],
  ['progress','Progresser','Courir plus vite ou plus longtemps, sans course précise','📈'],
  ['restart','(Re)commencer','Reprendre en douceur, sans se blesser','🌱'],
  ['weight','Perdre du poids','Un programme qui allie course et déficit calorique','🔥'],
  ['health','Rester en forme','Une routine régulière qui tient dans ta semaine','⚡']
];
const OB_DIST=[['5k','5 km'],['10k','10 km'],['semi','Semi'],['marathon','Marathon'],['other','Autre distance']];
const OB_LEVELS=[
  ['deb','Débutante','Je cours depuis moins de 6 mois'],
  ['inter','Intermédiaire','Je cours 2-3 fois par semaine'],
  ['conf','Confirmée','Je m\u2019entraîne sérieusement depuis des années']
];
const OB_DAYS=['L','M','M','J','V','S','D'];
const OB_CONNECT=[
  ['apple','Apple Santé','FC, sommeil, course','',  'ios'],
  ['strava','Strava','Historique & segments','', 'strava'],
  ['garmin','Garmin Connect','Montre & données avancées','', 'garmin']
];

function ObScreen({children}){
  return <div className="scan fade" style={{display:'flex',flexDirection:'column',padding:'0 22px'}}>{children}</div>;
}
function ObTitle({eye,title,sub}){
  return (
    <div style={{marginTop:18}}>
      <div className="eye" style={{color:R}}>{eye}</div>
      <div className="b" style={{fontSize:30,marginTop:6,lineHeight:.95}}>{title}</div>
      {sub && <div style={{fontSize:13,color:'var(--t2)',marginTop:10,lineHeight:1.5}}>{sub}</div>}
    </div>
  );
}
function ObNext({on,disabled,label='CONTINUER'}){
  return <button className="b btn-rose press" disabled={disabled} onClick={on} style={{marginBottom:24,opacity:disabled?.35:1}}>{label}</button>;
}
function ObProgress({step,total}){
  return (
    <div style={{display:'flex',gap:5,padding:'10px 22px 0',flexShrink:0}}>
      {Array.from({length:total},(_,i)=>(
        <div key={i} style={{flex:1,height:3,borderRadius:99,background:i<=step?R:'rgba(255,255,255,.1)',transition:'background .3s'}}></div>))}
    </div>
  );
}

function Onboarding({onDone}){
  const [showWelcome,setShowWelcome]=React.useState(true);
  const [step,setStep]=React.useState(0);
  const [name,setName]=React.useState('');
  const [birthdate,setBirthdate]=React.useState('');
  const [goal,setGoal]=React.useState(null);
  const [dist,setDist]=React.useState(null);
  const [customDist,setCustomDist]=React.useState('');
  const [chrono,setChrono]=React.useState(null);
  const [customChrono,setCustomChrono]=React.useState(false);
  const [raceDate,setRaceDate]=React.useState('');
  const [days,setDays]=React.useState([1,2,4,6]);
  const [level,setLevel]=React.useState('inter');
  const [connected,setConnected]=React.useState([]);
  const [connecting,setConnecting]=React.useState(null);
  const [built,setBuilt]=React.useState(0);
  /* objective-specific deep dive */
  const [weightNow,setWeightNow]=React.useState('');
  const [weightTarget,setWeightTarget]=React.useState('');
  const [height,setHeight]=React.useState('');
  const [focusArea,setFocusArea]=React.useState(null);
  const [bestPerf,setBestPerf]=React.useState('');
  const [lastRan,setLastRan]=React.useState(null);
  const [injury,setInjury]=React.useState(null);
  const [weeklyTime,setWeeklyTime]=React.useState(null);
  const [preferredTime,setPreferredTime]=React.useState(null);

  const isRace=goal==='race';
  const total=8;

  function age(bd){
    if(!bd) return null;
    const b=new Date(bd), today=new Date('2026-07-13');
    let a=today.getFullYear()-b.getFullYear();
    const m=today.getMonth()-b.getMonth();
    if(m<0||(m===0&&today.getDate()<b.getDate())) a--;
    return a;
  }
  function daysUntil(rd){
    if(!rd) return null;
    const today=new Date('2026-07-13');
    const d=new Date(rd);
    return Math.max(1,Math.round((d-today)/86400000));
  }

  /* building animation */
  React.useEffect(()=>{
    if(step!==total-1) return;
    setBuilt(0);
    const steps=[600,1300,2100,2900];
    const ts=steps.map((d,i)=>setTimeout(()=>setBuilt(i+1),d));
    const end=setTimeout(()=>onDone({name:name.trim()||'Léa',birthdate,age:age(birthdate),goal,dist,customDist,chrono,raceDate,raceIn:daysUntil(raceDate),days,level,
      weightNow,weightTarget,height,focusArea,bestPerf,lastRan,injury,weeklyTime,preferredTime}),3800);
    return ()=>{ts.forEach(clearTimeout);clearTimeout(end);};
  },[step]);

  const chronosFor={'5k':['20:00','22:30','25:00','28:00'],'10k':['42:00','47:30','52:00','58:00'],'semi':['1:40','1:50','2:00','2:15'],'marathon':['3:30','3:50','4:15','4:45']};

  function toggleConnect(id){
    if(connected.includes(id)){ setConnected(c=>c.filter(x=>x!==id)); return; }
    setConnecting(id);
    setTimeout(()=>{ setConnected(c=>[...c,id]); setConnecting(null); }, 1100);
  }

  const screens=[];

  /* 0 — prénom */
  screens.push(
    <ObScreen key="w">
      <div style={{flex:1,display:'flex',flexDirection:'column',justifyContent:'center'}}>
        <div className="eye" style={{color:R}}>Pour commencer</div>
        <div className="b" style={{fontSize:32,marginTop:8,lineHeight:.95}}>C'EST QUOI<br/>TON PRÉNOM ?</div>
        <div style={{fontSize:13,color:'var(--t2)',marginTop:12,lineHeight:1.5}}>Ton coach va s'adresser à toi — autant se présenter.</div>
        <div style={{marginTop:22}}>
          <input value={name} onChange={e=>setName(e.target.value)} placeholder="Léa" autoFocus
            style={{width:'100%',background:'var(--card)',border:'.5px solid var(--line)',borderRadius:14,padding:'14px 16px',color:'#fff',fontSize:16,fontFamily:'inherit',outline:'none'}}/>
        </div>
      </div>
      <ObNext on={()=>setStep(1)} label="CONTINUER" disabled={!name.trim()}/>
    </ObScreen>
  );

  /* 1 — date de naissance */
  screens.push(
    <ObScreen key="bd">
      <ObTitle eye={`Étape 1 · ${name.trim()||'toi'}`} title="TA DATE DE NAISSANCE ?" sub="Ça nous aide à calibrer tes zones de fréquence cardiaque et ton estimation VO₂max."/>
      <div style={{marginTop:22}}>
        <input type="date" value={birthdate} onChange={e=>setBirthdate(e.target.value)} max="2026-07-13" min="1930-01-01"
          style={{width:'100%',background:'var(--card)',border:'.5px solid var(--line)',borderRadius:14,padding:'14px 16px',color:'#fff',fontSize:16,fontFamily:'inherit',outline:'none',colorScheme:'dark'}}/>
        {birthdate && <div style={{marginTop:12,fontSize:13,color:'var(--t2)'}}>{age(birthdate)} ans</div>}
      </div>
      <div style={{flex:1}}></div>
      <ObNext on={()=>setStep(2)} disabled={!birthdate}/>
    </ObScreen>
  );

  /* 2 — objectif */
  screens.push(
    <ObScreen key="g">
      <ObTitle eye={`Étape 2 · ${name.trim()||'toi'}`} title="POURQUOI TU COURS ?" sub="C'est la base de tout ton programme."/>
      <div style={{display:'flex',flexDirection:'column',gap:8,marginTop:20,flex:1}}>
        {OB_GOALS.map(([id,t,s,e])=>(
          <button key={id} className="press" onClick={()=>setGoal(id)}
            style={{display:'flex',alignItems:'center',gap:14,textAlign:'left',padding:'15px 16px',borderRadius:18,
              background:goal===id?'rgba(255,15,91,.12)':'var(--card)',border:`.5px solid ${goal===id?'rgba(255,15,91,.4)':'var(--line)'}`}}>
            <span style={{fontSize:24}}>{e}</span>
            <div style={{flex:1}}><div style={{fontSize:15,fontWeight:600,color:'#fff'}}>{t}</div><div style={{fontSize:11.5,color:'var(--t2)',marginTop:2,lineHeight:1.35}}>{s}</div></div>
            <span style={{width:20,height:20,borderRadius:'50%',border:`2px solid ${goal===id?R:'rgba(255,255,255,.2)'}`,background:goal===id?R:'none',display:'flex',alignItems:'center',justifyContent:'center',fontSize:11,color:'#fff'}}>{goal===id?'✓':''}</span>
          </button>))}
      </div>
      <ObNext on={()=>setStep(3)} disabled={!goal}/>
    </ObScreen>
  );

  /* 3 — deep-dive personnalisé selon l'objectif */
  const Chip=({on,onClick,children})=>(
    <button className="press" onClick={onClick} style={{padding:'11px 15px',borderRadius:99,background:on?R:'var(--card)',border:`.5px solid ${on?R:'var(--line)'}`,color:'#fff',fontSize:13,fontWeight:600}}>{children}</button>
  );
  const NumField=({label,value,onChange,unit,placeholder})=>(
    <div style={{flex:1}}>
      <div className="eye" style={{color:'var(--t3)',marginBottom:8}}>{label}</div>
      <div style={{display:'flex',alignItems:'center',background:'var(--card)',border:'.5px solid var(--line)',borderRadius:14,padding:'13px 16px'}}>
        <input type="number" inputMode="numeric" value={value} onChange={e=>onChange(e.target.value)} placeholder={placeholder}
          style={{flex:1,background:'none',border:'none',outline:'none',color:'#fff',fontSize:16,fontFamily:'inherit',width:0}}/>
        <span style={{fontSize:12,color:'var(--t2)',fontWeight:600}}>{unit}</span>
      </div>
    </div>
  );

  let deepDiveOk=true, deepDiveNode=null;
  if(goal==='weight'){
    deepDiveOk=weightNow&&weightTarget&&height;
    deepDiveNode=(
      <React.Fragment>
        <div style={{display:'flex',gap:10,marginTop:20}}>
          <NumField label="Poids actuel" value={weightNow} onChange={setWeightNow} unit="kg" placeholder="70"/>
          <NumField label="Poids visé" value={weightTarget} onChange={setWeightTarget} unit="kg" placeholder="64"/>
        </div>
        <div style={{marginTop:12}}><NumField label="Taille" value={height} onChange={setHeight} unit="cm" placeholder="168"/></div>
        <div style={{marginTop:14,fontSize:11.5,color:'var(--t2)',lineHeight:1.5}}>On calcule ton déficit calorique cible et on l'allie à la course — sans jamais sacrifier ta forme.</div>
      </React.Fragment>
    );
  } else if(goal==='progress'){
    deepDiveOk=!!focusArea;
    deepDiveNode=(
      <React.Fragment>
        <div className="eye" style={{color:'var(--t3)',marginTop:20,marginBottom:10}}>Ta priorité</div>
        <div style={{display:'flex',flexWrap:'wrap',gap:8}}>
          {[['speed','Aller plus vite'],['endurance','Tenir plus longtemps'],['consistency','Être régulière'],['trail','Dénivelé / trail']].map(([id,l])=>(
            <Chip key={id} on={focusArea===id} onClick={()=>setFocusArea(id)}>{l}</Chip>))}
        </div>
        <div className="eye" style={{color:'var(--t3)',margin:'20px 2px 10px'}}>Ta meilleure perf récente <span style={{color:'var(--t3)',fontWeight:400,textTransform:'none',letterSpacing:0}}>(facultatif)</span></div>
        <input value={bestPerf} onChange={e=>setBestPerf(e.target.value)} placeholder="Ex. 10 km en 52 min"
          style={{width:'100%',background:'var(--card)',border:'.5px solid var(--line)',borderRadius:14,padding:'13px 16px',color:'#fff',fontSize:14,fontFamily:'inherit',outline:'none'}}/>
      </React.Fragment>
    );
  } else if(goal==='restart'){
    deepDiveOk=!!lastRan&&!!injury;
    deepDiveNode=(
      <React.Fragment>
        <div className="eye" style={{color:'var(--t3)',marginTop:20,marginBottom:10}}>Ta dernière sortie remonte à</div>
        <div style={{display:'flex',flexWrap:'wrap',gap:8}}>
          {[['1m','Moins d\'1 mois'],['6m','1 à 6 mois'],['1y','6 mois à 1 an'],['1y+','Plus d\'1 an']].map(([id,l])=>(
            <Chip key={id} on={lastRan===id} onClick={()=>setLastRan(id)}>{l}</Chip>))}
        </div>
        <div className="eye" style={{color:'var(--t3)',margin:'20px 2px 10px'}}>Une douleur ou blessure à surveiller ?</div>
        <div style={{display:'flex',flexWrap:'wrap',gap:8}}>
          {[['none','Aucune'],['knee','Genou'],['ankle','Cheville'],['back','Dos'],['other','Autre']].map(([id,l])=>(
            <Chip key={id} on={injury===id} onClick={()=>setInjury(id)}>{l}</Chip>))}
        </div>
      </React.Fragment>
    );
  } else {
    deepDiveOk=!!weeklyTime&&!!preferredTime;
    deepDiveNode=(
      <React.Fragment>
        <div className="eye" style={{color:'var(--t3)',marginTop:20,marginBottom:10}}>Temps que tu veux y consacrer / semaine</div>
        <div style={{display:'flex',flexWrap:'wrap',gap:8}}>
          {[['1h','Moins d\'1h'],['2h','1 à 2h'],['3h','2 à 3h'],['3h+','Plus de 3h']].map(([id,l])=>(
            <Chip key={id} on={weeklyTime===id} onClick={()=>setWeeklyTime(id)}>{l}</Chip>))}
        </div>
        <div className="eye" style={{color:'var(--t3)',margin:'20px 2px 10px'}}>Ton moment préféré pour courir</div>
        <div style={{display:'flex',flexWrap:'wrap',gap:8}}>
          {[['morning','Matin'],['noon','Midi'],['evening','Soir'],['varies','Ça varie']].map(([id,l])=>(
            <Chip key={id} on={preferredTime===id} onClick={()=>setPreferredTime(id)}>{l}</Chip>))}
        </div>
      </React.Fragment>
    );
  }
  if(!isRace) screens.push(
    <ObScreen key="dd">
      <ObTitle eye="Étape 3 · sur mesure" title={goal==='weight'?'TON POINT DE DÉPART':goal==='progress'?'TA PRIORITÉ':goal==='restart'?'AVANT DE REPRENDRE':'TON RYTHME IDÉAL'} sub="Plus on en sait, plus le plan colle à ta réalité."/>
      {deepDiveNode}
      <div style={{flex:1}}></div>
      <ObNext on={()=>setStep(4)} disabled={!deepDiveOk}/>
    </ObScreen>
  );

  /* 3 — (race only) distance + chrono + date */
  if(isRace) screens.push(
    <ObScreen key="d">
      <ObTitle eye="Étape 3 · ta course" title="QUELLE COURSE ?" sub="Route, trail, obstacle… précise ce que tu prépares."/>
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:8,marginTop:20}}>
        {OB_DIST.map(([id,l])=>(
          <button key={id} className="press" onClick={()=>{setDist(id);if(id!=='other'){setChrono(chronosFor[id][1]);setCustomChrono(false);}else{setChrono('');}}}
            style={{padding:'18px 6px',borderRadius:16,background:dist===id?'rgba(255,15,91,.12)':'var(--card)',border:`.5px solid ${dist===id?'rgba(255,15,91,.4)':'var(--line)'}`,gridColumn:id==='other'?'1 / -1':'auto'}}>
            <span className="b" style={{fontSize:id==='other'?16:22,color:dist===id?R2:'#fff'}}>{l}</span>
          </button>))}
      </div>
      {dist==='other' && (
        <div style={{marginTop:12}}>
          <input value={customDist} onChange={e=>setCustomDist(e.target.value)} placeholder="Ex. Trail 22 km, Ekiden, 15 km…"
            style={{width:'100%',background:'var(--card)',border:'.5px solid var(--line)',borderRadius:14,padding:'13px 16px',color:'#fff',fontSize:14,fontFamily:'inherit',outline:'none'}}/>
        </div>
      )}
      {dist && (
        <React.Fragment>
          <div className="eye" style={{color:'var(--t3)',margin:'22px 2px 10px'}}>Ton objectif chrono</div>
          <div style={{display:'flex',gap:7,flexWrap:'wrap'}}>
            {dist!=='other' && chronosFor[dist].map(t=>(
              <button key={t} className="press" onClick={()=>{setChrono(t);setCustomChrono(false);}}
                style={{padding:'10px 16px',borderRadius:99,background:chrono===t&&!customChrono?R:'var(--card)',border:`.5px solid ${chrono===t&&!customChrono?R:'var(--line)'}`,color:'#fff',fontSize:14,fontWeight:600}}>{t}</button>))}
            <button className="press" onClick={()=>{setChrono('finir');setCustomChrono(false);}}
              style={{padding:'10px 16px',borderRadius:99,background:chrono==='finir'?R:'var(--card)',border:`.5px solid ${chrono==='finir'?R:'var(--line)'}`,color:'#fff',fontSize:14,fontWeight:600}}>Juste finir 😅</button>
            <button className="press" onClick={()=>{setCustomChrono(true);setChrono('');}}
              style={{padding:'10px 16px',borderRadius:99,background:customChrono?R:'var(--card)',border:`.5px solid ${customChrono?R:'var(--line)'}`,color:'#fff',fontSize:14,fontWeight:600}}>Mon propre temps</button>
          </div>
          {customChrono && (
            <div style={{marginTop:10}}>
              <input value={chrono} onChange={e=>setChrono(e.target.value)} placeholder="Ex. 1:52:00" autoFocus
                style={{width:'100%',background:'var(--card)',border:'.5px solid var(--line)',borderRadius:14,padding:'13px 16px',color:'#fff',fontSize:14,fontFamily:'inherit',outline:'none'}}/>
            </div>
          )}
          <div className="eye" style={{color:'var(--t3)',margin:'22px 2px 10px'}}>Date de la course</div>
          <input type="date" value={raceDate} onChange={e=>setRaceDate(e.target.value)} min="2026-07-14"
            style={{width:'100%',background:'var(--card)',border:'.5px solid var(--line)',borderRadius:14,padding:'13px 16px',color:'#fff',fontSize:14,fontFamily:'inherit',outline:'none',colorScheme:'dark'}}/>
          {raceDate && <div style={{marginTop:10,fontSize:12,color:R2,fontWeight:600}}>J-{daysUntil(raceDate)}</div>}
        </React.Fragment>
      )}
      <div style={{flex:1}}></div>
      <ObNext on={()=>setStep(4)} disabled={!dist||(dist==='other'&&!customDist.trim())||!chrono||!raceDate}/>
    </ObScreen>
  );

  /* dispos */
  screens.push(
    <ObScreen key="j">
      <ObTitle eye={`Étape 4 · ton rythme`} title="TES JOURS DE COURSE" sub="Le programme se cale dessus — tu pourras toujours bouger une séance."/>
      <div style={{display:'flex',gap:7,marginTop:22}}>
        {OB_DAYS.map((d,i)=>{
          const on=days.includes(i);
          return <button key={i} className="press" onClick={()=>setDays(ds=>on?ds.filter(x=>x!==i):[...ds,i])}
            style={{flex:1,aspectRatio:'1',borderRadius:14,background:on?R:'var(--card)',border:`.5px solid ${on?R:'var(--line)'}`,display:'flex',alignItems:'center',justifyContent:'center'}}>
            <span className="b" style={{fontSize:15,color:on?'#fff':'var(--t2)'}}>{d}</span>
          </button>;})}
      </div>
      <div style={{marginTop:14,fontSize:12,color:days.length<2?'#FFB03D':'var(--t2)',textAlign:'center'}}>
        {days.length<2?'Choisis au moins 2 jours pour progresser':`${days.length} jours / semaine — bon rythme`}
      </div>
      <div style={{flex:1}}></div>
      <ObNext on={()=>setStep(5)} disabled={days.length<2}/>
    </ObScreen>
  );

  /* niveau */
  screens.push(
    <ObScreen key="n">
      <ObTitle eye={`Étape 5 · ton niveau`} title="OÙ TU EN ES ?"/>
      <div style={{display:'flex',flexDirection:'column',gap:8,marginTop:20,flex:1}}>
        {OB_LEVELS.map(([id,t,s])=>(
          <button key={id} className="press" onClick={()=>setLevel(id)}
            style={{textAlign:'left',padding:'16px',borderRadius:18,background:level===id?'rgba(255,15,91,.12)':'var(--card)',border:`.5px solid ${level===id?'rgba(255,15,91,.4)':'var(--line)'}`}}>
            <div style={{fontSize:15,fontWeight:600,color:'#fff'}}>{t}</div>
            <div style={{fontSize:11.5,color:'var(--t2)',marginTop:3}}>{s}</div>
          </button>))}
      </div>
      <ObNext on={()=>setStep(6)} label="SUIVANT"/>
    </ObScreen>
  );

  /* connexions santé */
  screens.push(
    <ObScreen key="c">
      <ObTitle eye={`Étape 6 · tes données`} title="CONNECTE TA MONTRE" sub="Pour une forme du jour plus précise — FC, sommeil, sorties passées. Facultatif, tu peux le faire plus tard."/>
      <div style={{display:'flex',flexDirection:'column',gap:8,marginTop:22,flex:1}}>
        {OB_CONNECT.map(([id,name,desc])=>{
          const on=connected.includes(id);
          const busy=connecting===id;
          return (
            <button key={id} className="press" onClick={()=>toggleConnect(id)}
              style={{display:'flex',alignItems:'center',gap:14,textAlign:'left',padding:'15px 16px',borderRadius:18,
                background:on?'rgba(200,255,61,.1)':'var(--card)',border:`.5px solid ${on?'rgba(200,255,61,.35)':'var(--line)'}`}}>
              <div style={{width:40,height:40,borderRadius:12,background:'rgba(255,255,255,.06)',display:'flex',alignItems:'center',justifyContent:'center',fontSize:18,flexShrink:0}}>
                {id==='apple'?'🍎':id==='strava'?'🟠':'⌚'}
              </div>
              <div style={{flex:1}}><div style={{fontSize:15,fontWeight:600,color:'#fff'}}>{name}</div><div style={{fontSize:11.5,color:'var(--t2)',marginTop:2}}>{desc}</div></div>
              {busy ? <span className="dots"><span></span><span></span><span></span></span> :
                on ? <span className="b" style={{fontSize:11,color:LIME,letterSpacing:.5}}>CONNECTÉ ✓</span> :
                <span style={{fontSize:11,color:'var(--t2)',fontWeight:600,padding:'6px 12px',borderRadius:99,border:'.5px solid var(--line)'}}>Connecter</span>}
            </button>);
        })}
      </div>
      <ObNext on={()=>setStep(7)} label={connected.length?'CONTINUER':'PLUS TARD'}/>
    </ObScreen>
  );

  /* building */
  const buildSteps=[
    'Ton profil analysé',
    'Ta forme de départ estimée',
    `Séances calées sur tes ${days.length} jours`,
    isRace?`Objectif ${dist==='other'?(customDist||'ta course'):(OB_DIST.find(x=>x[0]===dist)||[,'ta course'])[1]} sécurisé`:'Progression sécurisée'
  ];
  screens.push(
    <ObScreen key="b">
      <div style={{flex:1,display:'flex',flexDirection:'column',justifyContent:'center'}}>
        <div style={{textAlign:'center'}}>
          <Ring pct={built/4*100} color={R} size={110} sw={7}>
            <span className="b" style={{fontSize:30,color:built===4?LIME:'#fff'}}>{built===4?'✓':Math.round(built/4*100)+'%'}</span>
          </Ring>
          <div className="b" style={{fontSize:28,marginTop:22,lineHeight:.95}}>ON CONSTRUIT<br/>TON PROGRAMME</div>
        </div>
        <div style={{marginTop:26}}>
          {buildSteps.map((t,i)=>(
            <div key={i} style={{display:'flex',alignItems:'center',gap:14,padding:'13px 4px',borderBottom:'.5px solid rgba(255,255,255,.06)',opacity:built>i?1:built===i?.9:.35,transition:'opacity .4s'}}>
              <div style={{width:24,height:24,borderRadius:'50%',flexShrink:0,display:'flex',alignItems:'center',justifyContent:'center',fontSize:11,
                background:built>i?R:'rgba(255,255,255,.06)',border:built>i?'none':'1px solid rgba(255,255,255,.15)',color:built>i?'#fff':'var(--t3)'}}>
                {built>i?'✓':built===i?<span className="pulse">●</span>:'○'}</div>
              <span style={{fontSize:14,color:built>i?'#fff':'var(--t2)'}}>{t}</span>
            </div>))}
        </div>
      </div>
      <div style={{textAlign:'center',fontSize:11,color:'var(--t3)',marginBottom:24}}>{built===4?'Prêt !':'9 semaines en préparation…'}</div>
    </ObScreen>
  );

  if(showWelcome) return (
    <div style={{position:'absolute',inset:0,display:'flex',flexDirection:'column',background:'radial-gradient(90% 60% at 50% 0%,rgba(255,15,91,.22),transparent 60%),var(--bg)',zIndex:100,overflow:'hidden'}}>
      <div className="scan fade" style={{display:'flex',flexDirection:'column',padding:'0 26px'}}>
        <div style={{flex:1,display:'flex',flexDirection:'column',justifyContent:'center',paddingTop:60}}>
          <div style={{width:88,height:88,borderRadius:26,boxShadow:'0 20px 50px rgba(255,15,91,.4)'}}>
            <AppMark size={88} radius={26}/>
          </div>
          <div className="b" style={{fontSize:42,marginTop:24,lineHeight:.92}}>COURS COMME<br/>SI TU AVAIS<br/>UN COACH</div>
          <div style={{fontSize:14,color:'var(--t2)',marginTop:14,lineHeight:1.55}}>RUNUP construit ton programme, l'ajuste après chaque sortie, et te pousse juste ce qu'il faut — jamais plus, jamais moins.</div>

          <div style={{display:'flex',flexDirection:'column',gap:14,marginTop:30}}>
            {[
              [<path d="M13 2 L4 14h6l-1 8 9-12h-6z"/>,'Un plan qui vit avec toi','Pas un PDF figé — il change selon ta forme et ton ressenti après chaque séance.'],
              [<g><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/></g>,'Tes anneaux, comme sur ta montre','Bouger, rester actif, courir — trois objectifs simples à boucler chaque jour.'],
              [<path d="M4 4h16v11H8l-4 4V4z"/>,'Un vrai coach, pas un chatbot','Il connaît ton objectif, ton historique, et te répond comme un humain le ferait.']
            ].map(([icon,t,d],i)=>(
              <div key={i} style={{display:'flex',gap:14,alignItems:'flex-start'}}>
                <div style={{width:38,height:38,borderRadius:12,background:'var(--card)',border:'.5px solid var(--line)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
                  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke={R2} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{icon}</svg>
                </div>
                <div><div style={{fontSize:14,fontWeight:600}}>{t}</div><div style={{fontSize:12,color:'var(--t2)',marginTop:3,lineHeight:1.4}}>{d}</div></div>
              </div>))}
          </div>

          <div style={{display:'flex',alignItems:'center',gap:8,marginTop:28,fontSize:11.5,color:'var(--t3)'}}>
            <span style={{color:LIME}}>★★★★★</span><span>Rejoins des milliers de coureurs qui progressent chaque semaine</span>
          </div>
        </div>
        <ObNext on={()=>setShowWelcome(false)} label="COMMENCER"/>
      </div>
    </div>
  );

  return (
    <div style={{position:'absolute',inset:0,display:'flex',flexDirection:'column',background:'radial-gradient(90% 50% at 50% 0%,rgba(255,15,91,.16),transparent 60%),var(--bg)',zIndex:100}}>
      <div style={{height:44,flexShrink:0}}></div>
      <ObProgress step={step} total={total}/>
      <div style={{flex:1,display:'flex',flexDirection:'column',overflow:'hidden'}}>{screens[step]}</div>
    </div>
  );
}

Object.assign(window,{Onboarding});
