/* ═══ RUNUP 4.0 — screens D : Fin de programme · récupération · nouvel objectif · course libre ═══ */

const RECOVERY_DAYS={race:6,weight:3,progress:4,restart:5,health:3};
const NG_GOALS=[
  ['race','Préparer une course','🏁'],
  ['progress','Progresser','📈'],
  ['weight','Perdre du poids','🔥'],
  ['health','Rester en forme','⚡']
];
const NG_DIST=[['5k','5 km'],['10k','10 km'],['semi','Semi'],['marathon','Marathon']];
const NG_CHRONOS={'5k':['20:00','22:30','25:00'],'10k':['42:00','47:30','52:00'],'semi':['1:40','1:50','2:00'],'marathon':['3:30','3:50','4:15']};

const FREE_RUN_TEMPLATES=[
  {title:'Footing d\u2019entretien',sub:'allure confort · reconnecte avec le plaisir de courir',dur:35,pace:'5:40',zone:'Z2'},
  {title:'Fractionné léger 5 × 500 m',sub:'récup 300 m · garde le tonus sans se cramer',dur:32,pace:'4:35',zone:'Z3'},
  {title:'Sortie découverte',dur:45,sub:'change d\u2019itinéraire, explore un nouveau parcours',pace:'5:30',zone:'Z2'}
];

/* ---------- RECOVERY (post-programme) ---------- */
function RecoveryView(){
  const c=React.useContext(Ctx), s=c.store;
  const total=RECOVERY_DAYS[s.goalId]||4;
  const done=total-s.recoveryDaysLeft;
  return (
    <div className="scan fade" style={{paddingBottom:120}}>
      <div className="pad" style={{paddingTop:8}}>
        <Header eye="Programme terminé 🏁" title={`Bravo ${s.name}`} right={
          <button className="press" onClick={()=>c.go('profile')} style={{width:36,height:36,borderRadius:'50%',background:R,display:'flex',alignItems:'center',justifyContent:'center'}}><span className="b" style={{color:'#fff'}}>{s.name[0]}</span></button>
        }/>
        <div style={{background:'linear-gradient(160deg,#20101C,#0E0E14)',border:'.5px solid rgba(255,15,91,.22)',borderRadius:22,padding:'22px 18px',textAlign:'center',marginTop:8}}>
          <div style={{fontSize:34}}>🌿</div>
          <div className="b" style={{fontSize:22,marginTop:10}}>Place à la récupération</div>
          <div style={{fontSize:12.5,color:'var(--t2)',marginTop:8,lineHeight:1.5}}>Ton corps a fait le plus dur. On souffle {total} jours avant de repartir — c'est ce qui fait tenir les progrès dans la durée.</div>
          <div style={{display:'flex',gap:5,justifyContent:'center',marginTop:18}}>
            {Array.from({length:total},(_,i)=>(
              <div key={i} style={{width:34,height:34,borderRadius:10,background:i<done?LIME:'rgba(255,255,255,.06)',border:`.5px solid ${i<done?LIME:'var(--line)'}`,display:'flex',alignItems:'center',justifyContent:'center'}}>
                <span className="b" style={{fontSize:13,color:i<done?'#0A0A0A':'var(--t2)'}}>{i<done?'✓':i+1}</span>
              </div>))}
          </div>
        </div>
        <div className="card" style={{padding:16,marginTop:14}}>
          <div className="eye" style={{color:R2}}>Aujourd'hui</div>
          <div style={{fontSize:14,fontWeight:600,marginTop:6}}>Marche, étirements ou repos complet</div>
          <div style={{fontSize:12,color:'var(--t2)',marginTop:6,lineHeight:1.5}}>Pas de course prévue — hydrate-toi bien et dors un peu plus si tu peux.</div>
        </div>
        <button className="b btn-rose press" style={{marginTop:16}} onClick={c.tickRecovery}>
          {s.recoveryDaysLeft>1?'JOUR SUIVANT →':'JE SUIS PRÊTE'}
        </button>
      </div>
    </div>
  );
}

/* ---------- CHOICE : nouvel objectif ou course libre ---------- */
function ChoiceView(){
  const c=React.useContext(Ctx), s=c.store;
  const [mode,setMode]=useState(null); // null | 'newgoal'
  const totalKm=((s.rings?.run?.v||0)+ (s.history||[]).reduce((a,h)=>a+h.dist,0)+40).toFixed(0);

  if(mode==='newgoal') return <NewGoalFlow onCancel={()=>setMode(null)}/>;

  return (
    <div className="scan fade" style={{paddingBottom:120}}>
      <div className="pad" style={{paddingTop:8}}>
        <Header eye="Récupération terminée" title="Et maintenant ?"/>
        <div style={{background:'var(--card)',border:'.5px solid var(--line)',borderRadius:18,padding:16,marginBottom:16}}>
          <div className="eye" style={{color:'var(--t2)'}}>Bilan de ton programme</div>
          <div style={{display:'flex',gap:20,marginTop:10}}>
            <div className="metric"><span className="v">{totalKm}</span><span className="l">km parcourus</span></div>
            <div className="metric"><span className="v">9</span><span className="l">semaines</span></div>
            <div className="metric"><span className="v" style={{color:R2}}>{s.streak}</span><span className="l">jours de série</span></div>
          </div>
        </div>
        <button className="press" onClick={()=>setMode('newgoal')} style={{width:'100%',textAlign:'left',display:'flex',alignItems:'center',gap:14,padding:'18px 16px',borderRadius:20,background:'linear-gradient(160deg,#20101C,#0E0E14)',border:'.5px solid rgba(255,15,91,.28)',marginBottom:10}}>
          <span style={{fontSize:26}}>🎯</span>
          <div style={{flex:1}}><div className="b" style={{fontSize:17}}>Se fixer un nouvel objectif</div><div style={{fontSize:11.5,color:'var(--t2)',marginTop:3,lineHeight:1.4}}>Une nouvelle course, progresser encore, perdre du poids…</div></div>
          <span style={{color:R2,fontSize:18}}>→</span>
        </button>
        <button className="press" onClick={c.chooseFreeRun} style={{width:'100%',textAlign:'left',display:'flex',alignItems:'center',gap:14,padding:'18px 16px',borderRadius:20,background:'var(--card)',border:'.5px solid var(--line)'}}>
          <AppMark size={26} radius={8}/>
          <div style={{flex:1}}><div className="b" style={{fontSize:17}}>Mode course libre</div><div style={{fontSize:11.5,color:'var(--t2)',marginTop:3,lineHeight:1.4}}>Pas d'objectif précis — on te propose juste de quoi garder la forme.</div></div>
          <span style={{color:'var(--t2)',fontSize:18}}>→</span>
        </button>
      </div>
    </div>
  );
}

/* ---------- NEW GOAL (compact wizard) ---------- */
function NewGoalFlow({onCancel}){
  const c=React.useContext(Ctx);
  const [step,setStep]=useState(0);
  const [goal,setGoal]=useState(null);
  const [dist,setDist]=useState('10k');
  const [chrono,setChrono]=useState(NG_CHRONOS['10k'][1]);
  const [days,setDays]=useState([1,2,4,6]);
  const [building,setBuilding]=useState(false);
  const isRace=goal==='race';

  React.useEffect(()=>{
    if(!building) return;
    const t=setTimeout(()=>c.startNewProgram({goal,dist,chrono,days}),2200);
    return ()=>clearTimeout(t);
  },[building]);

  if(building) return (
    <div className="scan fade" style={{display:'flex',flexDirection:'column',justifyContent:'center',alignItems:'center',height:'100%'}}>
      <Ring pct={70} color={R} size={100} sw={7}><span className="b" style={{fontSize:26}}>🎯</span></Ring>
      <div className="b" style={{fontSize:22,marginTop:20,textAlign:'center'}}>Ton nouveau<br/>programme arrive</div>
    </div>
  );

  return (
    <div className="scan fade" style={{paddingBottom:120}}>
      <div className="pad" style={{paddingTop:8}}>
        <div style={{display:'flex',alignItems:'center',gap:12,margin:'2px 0 16px'}}>
          <button className="press" onClick={step===0?onCancel:()=>setStep(step-1)} style={{fontSize:22,color:'var(--t2)'}}>‹</button>
          <div className="b" style={{fontSize:20}}>Nouvel objectif</div>
        </div>

        {step===0 && (
          <div style={{display:'flex',flexDirection:'column',gap:8}}>
            {NG_GOALS.map(([id,t,e])=>(
              <button key={id} className="press" onClick={()=>setGoal(id)}
                style={{display:'flex',alignItems:'center',gap:14,textAlign:'left',padding:'15px 16px',borderRadius:18,
                  background:goal===id?'rgba(255,15,91,.12)':'var(--card)',border:`.5px solid ${goal===id?'rgba(255,15,91,.4)':'var(--line)'}`}}>
                <span style={{fontSize:22}}>{e}</span>
                <span style={{flex:1,fontSize:15,fontWeight:600}}>{t}</span>
              </button>))}
            <button className="b btn-rose press" style={{marginTop:8}} disabled={!goal} onClick={()=>setStep(isRace?1:2)}>CONTINUER</button>
          </div>
        )}

        {step===1 && isRace && (
          <div>
            <div className="eye" style={{color:'var(--t3)',marginBottom:10}}>Distance</div>
            <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:8}}>
              {NG_DIST.map(([id,l])=>(
                <button key={id} className="press" onClick={()=>{setDist(id);setChrono(NG_CHRONOS[id][1]);}}
                  style={{padding:'16px 6px',borderRadius:16,background:dist===id?'rgba(255,15,91,.12)':'var(--card)',border:`.5px solid ${dist===id?'rgba(255,15,91,.4)':'var(--line)'}`}}>
                  <span className="b" style={{fontSize:20,color:dist===id?R2:'#fff'}}>{l}</span>
                </button>))}
            </div>
            <div className="eye" style={{color:'var(--t3)',margin:'20px 0 10px'}}>Chrono visé</div>
            <div style={{display:'flex',gap:7,flexWrap:'wrap'}}>
              {NG_CHRONOS[dist].map(t=>(
                <button key={t} className="press" onClick={()=>setChrono(t)}
                  style={{padding:'10px 16px',borderRadius:99,background:chrono===t?R:'var(--card)',border:`.5px solid ${chrono===t?R:'var(--line)'}`,color:'#fff',fontSize:14,fontWeight:600}}>{t}</button>))}
            </div>
            <button className="b btn-rose press" style={{marginTop:20}} onClick={()=>setStep(2)}>CONTINUER</button>
          </div>
        )}

        {step===2 && (
          <div>
            <div className="eye" style={{color:'var(--t3)',marginBottom:10}}>Tes jours de course</div>
            <div style={{display:'flex',gap:7}}>
              {['L','M','M','J','V','S','D'].map((d,i)=>{
                const on=days.includes(i);
                return <button key={i} className="press" onClick={()=>setDays(ds=>on?ds.filter(x=>x!==i):[...ds,i])}
                  style={{flex:1,aspectRatio:'1',borderRadius:14,background:on?R:'var(--card)',border:`.5px solid ${on?R:'var(--line)'}`,display:'flex',alignItems:'center',justifyContent:'center'}}>
                  <span className="b" style={{fontSize:15,color:on?'#fff':'var(--t2)'}}>{d}</span>
                </button>;})}
            </div>
            <button className="b btn-rose press" style={{marginTop:20}} disabled={days.length<2} onClick={()=>setBuilding(true)}>CONSTRUIRE MON PROGRAMME</button>
          </div>
        )}
      </div>
    </div>
  );
}

Object.assign(window,{RECOVERY_DAYS,FREE_RUN_TEMPLATES,RecoveryView,ChoiceView,NewGoalFlow});
