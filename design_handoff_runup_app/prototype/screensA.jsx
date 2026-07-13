/* ═══ RUNUP 4.0 — screens A : Programme · Plan · Anneaux · Live · Recap ═══ */
const fmt=s=>`${Math.floor(s/60)}:${String(Math.floor(s%60)).padStart(2,'0')}`;
const fmtH=s=>{const h=Math.floor(s/3600),m=Math.floor((s%3600)/60);return h?`${h}h${String(m).padStart(2,'0')}`:`${m}′`;};

/* ---------- PROGRAMME (home) ---------- */
function ProgScreen(){
  const c=React.useContext(Ctx), s=c.store;
  const rg=s.rings;
  if(s.programPhase==='recovery') return <RecoveryView/>;
  if(s.programPhase==='choice') return <ChoiceView/>;
  const freerun=s.programPhase==='freerun';
  return (
    <div className="scan fade" style={{paddingBottom:120}}>
      <div className="pad" style={{paddingTop:8}}>
        <Header eye={freerun?"Vendredi 12 · Mode course libre":`Vendredi 12 · Semaine ${s.week_no}`} title={`Salut ${s.name}`} right={
          <div style={{display:'flex',alignItems:'center',gap:8}}>
            <button className="press" onClick={c.openNotifs} style={{position:'relative',width:36,height:36,borderRadius:'50%',background:'var(--card)',border:'.5px solid var(--line)',display:'flex',alignItems:'center',justifyContent:'center'}}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 0 1-3.4 0"/></svg>
              {c.unreadCount>0 && <span style={{position:'absolute',top:6,right:7,width:8,height:8,borderRadius:'50%',background:R,border:'1.5px solid var(--bg)'}}></span>}
            </button>
            <button className="press" onClick={()=>c.go('profile')} style={{width:36,height:36,borderRadius:'50%',background:R,display:'flex',alignItems:'center',justifyContent:'center'}}><span className="b" style={{color:'#fff'}}>{s.name[0]}</span></button>
          </div>
        }/>
        <button className="press" onClick={c.replayOb} style={{fontSize:10.5,color:'var(--t3)',fontWeight:600,marginBottom:12,display:'flex',alignItems:'center',gap:5}}>
          <span style={{fontSize:12}}>↺</span> Revoir l'intro
        </button>
        {/* week strip */}
        <div style={{display:'flex',gap:5,marginBottom:14}}>
          {s.week.map((d,i)=>{
            let bg='var(--card)',bd='var(--line)',col='var(--t2)',mk='';
            if(d.st==='done'){bg=R;bd=R;col='#fff';mk='✓';}
            if(d.st==='today'){bd='rgba(255,15,91,.5)';bg='rgba(255,15,91,.12)';col=R2;}
            if(d.st==='rest'){col='var(--t4)';mk='·';}
            return <div key={i} style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',gap:5,padding:'10px 0',borderRadius:14,background:bg,border:`.5px solid ${bd}`}}>
              <span className="b" style={{fontSize:11,color:col}}>{d.d}</span><span style={{fontSize:11,color:col}}>{mk}</span></div>;
          })}
        </div>
        {/* forme du jour */}
        <div className="press" onClick={()=>c.go('rings')} style={{background:'linear-gradient(160deg,#20101C,#0E0E14)',border:'.5px solid rgba(255,15,91,.2)',borderRadius:20,padding:'15px 16px',display:'flex',alignItems:'center',gap:14,marginBottom:12}}>
          <Ring pct={s.readiness} color={LIME} size={64}><span className="b" style={{fontSize:20,color:LIME}}>{s.readiness}</span></Ring>
          <div style={{flex:1}}>
            <div className="eye" style={{color:'var(--t2)'}}>Forme du jour · excellente</div>
            <div style={{fontSize:12,color:'rgba(255,255,255,.7)',marginTop:5,lineHeight:1.4}}>Bien récupérée → séance relevée d'un palier aujourd'hui.</div>
          </div>
        </div>
        {/* today session */}
        <div className="card press" onClick={c.openSessionDetail} style={{padding:16}}>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:10}}>
            <div className="eye" style={{color:R}}>{s.day} · séance clé</div>
            {s.session.adj && <span className="chip" style={{background:'rgba(255,15,91,.14)',color:R2}}>{s.session.adj}</span>}
          </div>
          <div className="b" style={{fontSize:23}}>{s.session.title}</div>
          <div style={{fontSize:11,color:'var(--t2)',marginTop:4}}>{s.session.sub}</div>
          <div style={{display:'flex',gap:16,marginTop:14}}>
            <div className="metric"><span className="v">{s.session.dur}′</span><span className="l">Durée</span></div>
            <div className="metric"><span className="v">{s.session.pace}</span><span className="l">Allure</span></div>
            <div className="metric"><span className="v" style={{color:R2}}>{s.session.zone}</span><span className="l">Zone</span></div>
          </div>
          <button className="b btn-rose press" style={{marginTop:15}} onClick={(e)=>{e.stopPropagation();c.startRun();}}>▶  DÉMARRER</button>
        </div>
        {/* rings — full width, promoted */}
        <div className="press card" onClick={()=>c.go('rings')} style={{padding:16,marginTop:12,display:'flex',alignItems:'center',gap:16}}>
          <Rings3 vals={[rg.move.v/rg.move.goal*100,rg.active.v/rg.active.goal*100,rg.run.v/rg.run.goal*100]} size={72} sw={6} gap={3}/>
          <div style={{flex:1}}>
            <div className="eye" style={{color:'var(--t2)'}}>Tes anneaux · {s.ringsDone}/3 bouclés</div>
            <div style={{display:'flex',gap:14,marginTop:8}}>
              <div><div className="b" style={{fontSize:16,color:R}}>{rg.move.v}</div><div style={{fontSize:8,color:'var(--t2)'}}>/{rg.move.goal} KCAL</div></div>
              <div><div className="b" style={{fontSize:16,color:LIME}}>{rg.active.v}</div><div style={{fontSize:8,color:'var(--t2)'}}>/{rg.active.goal} MIN</div></div>
              <div><div className="b" style={{fontSize:16,color:CYAN}}>{rg.run.v}</div><div style={{fontSize:8,color:'var(--t2)'}}>/{rg.run.goal} KM</div></div>
            </div>
          </div>
        </div>
        {/* plan — full width, phase bar teaser */}
        {!freerun ? (
          <div className="press card" onClick={()=>c.go('plan')} style={{padding:16,marginTop:10}}>
            <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
              <div className="eye" style={{color:R}}>Objectif · {s.goal} · J-{s.raceIn}</div>
              <span style={{color:R2,fontSize:14}}>→</span>
            </div>
            <div className="b" style={{fontSize:17,marginTop:4}}>Semaine {s.week_no} · Bloc VMA</div>
            <div style={{display:'flex',gap:4,marginTop:10}}>
              {[['Base',3,3,R],['Spécifique',1,4,R2],['Affûtage',0,2,VIO]].map(([n,d,t,col])=>(
                <div key={n} style={{flex:t}}><div className="bar"><i style={{width:`${d/t*100}%`,background:col}}></i></div></div>))}
            </div>
            <div style={{fontSize:10,color:'var(--t2)',marginTop:7}}>9 semaines · voir le plan complet</div>
          </div>
        ) : (
          <div style={{marginTop:12,textAlign:'center',fontSize:11,color:'var(--t3)'}}>Pas de plan fixe — le coach te propose de quoi garder la forme, jour après jour.</div>
        )}
      </div>
    </div>
  );
}

/* ---------- PLAN complet ---------- */
function PlanScreen(){
  const c=React.useContext(Ctx), s=c.store;
  const sess=[['Lun','Récup active','30′ · Z2',CYAN,'done'],['Mar','Fractionné 6×800','48′ · Z4',R,'done'],['Mer','Repos','—','rgba(255,255,255,.2)','rest'],['Jeu',s.session.title,`${s.session.dur}′ · ${s.session.zone}`,R,'today'],['Ven','Récup active','30′ · Z2',CYAN,''],['Sam','Sortie longue','1h05 · Z2-3',R2,''],['Dim','Repos','—','rgba(255,255,255,.2)','rest']];
  const weeks=[['1','Base','32 km','done'],['2','Base','35 km','done'],['3','Base','34 km','done'],['4','VMA · en cours','33 km','current'],['5','Spécifique','38 km',''],['6','Spécifique','40 km',''],['7','Spécifique','36 km',''],['8','Affûtage','28 km','taper'],['9','Course','10 km','race']];
  return (
    <div className="scan fade" style={{paddingBottom:120}}>
      <div className="pad" style={{paddingTop:8}}>
        <div style={{display:'flex',alignItems:'center',gap:12,margin:'2px 0 8px'}}>
          <button className="press" onClick={()=>c.go('prog')} style={{fontSize:22,color:'var(--t2)'}}>‹</button>
          <div><div className="eye" style={{color:R}}>Ton programme · {s.goal}</div><div className="b" style={{fontSize:22}}>Le plan complet</div></div>
        </div>
        <div style={{fontSize:12,color:'var(--t2)',lineHeight:1.5,margin:'0 0 14px'}}>9 semaines · 3 phases. Il évolue à chaque séance selon ta forme.</div>
        <div style={{display:'flex',gap:4,marginBottom:14}}>
          {[['Base',3,3,R],['Spécifique',1,4,R2],['Affûtage',0,2,VIO]].map(([n,d,t,col])=>(
            <div key={n} style={{flex:t}}><div className="bar"><i style={{width:`${d/t*100}%`,background:col}}></i></div><div style={{fontSize:8,letterSpacing:1,textTransform:'uppercase',color:'var(--t2)',fontWeight:700,marginTop:6}}>{n}</div></div>))}
        </div>
        <div style={{display:'flex',flexDirection:'column',gap:6}}>
          {weeks.map(([n,ph,km,st])=>{
            if(st==='current') return (
              <div key={n} style={{background:'var(--card)',border:'.5px solid rgba(255,15,91,.3)',borderRadius:16,overflow:'hidden'}}>
                <div style={{display:'flex',alignItems:'center',gap:12,padding:'13px 14px',background:'rgba(255,15,91,.08)'}}>
                  <div className="b" style={{width:30,height:30,borderRadius:9,background:R,display:'flex',alignItems:'center',justifyContent:'center'}}>{n}</div>
                  <div style={{flex:1}}><div style={{fontSize:13,fontWeight:600}}>Semaine {n} · {ph}</div><div style={{fontSize:10,color:'var(--t2)',marginTop:1}}>{km} · 2/4 séances faites</div></div>
                  <span style={{color:R2}}>▾</span>
                </div>
                <div style={{padding:'6px 12px 12px'}}>
                  {sess.map((x,i)=>(
                    <div key={i} style={{display:'flex',alignItems:'center',gap:11,padding:'9px 4px'}}>
                      <span className="b" style={{fontSize:10,color:'var(--t2)',width:26}}>{x[0]}</span>
                      <span style={{width:6,height:6,borderRadius:'50%',background:x[3],flexShrink:0,opacity:x[4]==='done'?1:.5}}></span>
                      <div style={{flex:1}}><span style={{fontSize:12.5,fontWeight:x[4]==='today'?600:400,color:x[4]==='rest'?'var(--t3)':'#fff'}}>{x[1]}</span>{x[4]==='today'&&<span className="chip" style={{background:'rgba(255,15,91,.15)',color:R2,padding:'2px 7px',fontSize:9,marginLeft:6}}>aujourd’hui</span>}</div>
                      <span className="m" style={{fontSize:10,color:'var(--t2)'}}>{x[2]}</span>
                      {x[4]==='done'?<span style={{color:R,fontSize:11}}>✓</span>:<span style={{width:11}}></span>}
                    </div>))}
                </div>
              </div>);
            const done=st==='done', badge=st==='race'?'🏁':st==='taper'?'▽':done?'✓':'›';
            const col=st==='race'?R:st==='taper'?VIO:done?'var(--t3)':'var(--t2)';
            return (
              <div key={n} style={{display:'flex',alignItems:'center',gap:12,background:'var(--card2)',border:`.5px solid ${st==='race'?'rgba(255,15,91,.25)':'var(--line)'}`,borderRadius:16,padding:'13px 14px',opacity:done?.6:1}}>
                <div className="b" style={{width:30,height:30,borderRadius:9,background:done?'rgba(255,255,255,.06)':st==='race'?'rgba(255,15,91,.15)':'rgba(255,255,255,.05)',border:'.5px solid var(--line)',display:'flex',alignItems:'center',justifyContent:'center',color:col}}>{n}</div>
                <div style={{flex:1}}><div style={{fontSize:13,fontWeight:500}}>Semaine {n} · {ph}</div><div style={{fontSize:10,color:'var(--t2)',marginTop:1}}>{km}</div></div>
                <span style={{color:col,fontSize:13}}>{badge}</span>
              </div>);
          })}
        </div>
      </div>
    </div>
  );
}

/* ---------- ANNEAUX ---------- */
function RingsScreen(){
  const c=React.useContext(Ctx), s=c.store, rg=s.rings;
  const meta=[['Bouger',R,rg.move,'kcal'],['Actif',LIME,rg.active,'min actives'],['Courir',CYAN,rg.run,'km du jour']];
  const remain=(rg.run.goal-rg.run.v).toFixed(1);
  return (
    <div className="scan fade" style={{paddingBottom:120}}>
      <div className="pad" style={{paddingTop:8}}>
        <div style={{display:'flex',alignItems:'center',gap:12,margin:'2px 0 8px'}}>
          <button className="press" onClick={()=>c.go('prog')} style={{fontSize:22,color:'var(--t2)'}}>‹</button>
          <div><div className="eye" style={{color:R}}>Aujourd'hui · vendredi 12</div><div className="b" style={{fontSize:22}}>Ta journée</div></div>
        </div>
        <div style={{display:'flex',justifyContent:'center',margin:'10px 0 6px'}}>
          <Rings3 vals={meta.map(m=>m[2].v/m[2].goal*100)} size={210} sw={18} gap={6}>
            <div style={{textAlign:'center'}}><div className="b" style={{fontSize:15,color:'var(--t2)',letterSpacing:1}}>{s.ringsDone} / 3</div><div style={{fontSize:9,color:'var(--t3)',marginTop:2}}>bouclés</div></div>
          </Rings3>
        </div>
        <div style={{display:'flex',flexDirection:'column',gap:9,marginTop:8}}>
          {meta.map(([n,col,val,unit])=>(
            <div key={n} style={{display:'flex',alignItems:'center',gap:12,background:'var(--card)',border:'.5px solid var(--line)',borderRadius:16,padding:'12px 14px'}}>
              <span style={{width:10,height:10,borderRadius:'50%',background:col,boxShadow:`0 0 12px ${col}66`,flexShrink:0}}></span>
              <div style={{flex:1}}>
                <div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline'}}><span className="b" style={{fontSize:16}}>{n}</span><span className="m" style={{fontSize:11,color:'var(--t2)'}}><b style={{color:col,fontFamily:'DM Sans'}}>{val.v}</b> / {val.goal} {unit}</span></div>
                <div className="bar" style={{marginTop:8}}><i style={{width:`${Math.min(val.v/val.goal*100,100)}%`,background:col}}></i></div>
              </div>
            </div>))}
        </div>
        {s.ringsDone<3 ? (
          <div style={{marginTop:12,background:'linear-gradient(160deg,#20101C,#0E0E14)',border:'.5px solid rgba(255,15,91,.22)',borderRadius:18,padding:'14px 15px',display:'flex',alignItems:'center',gap:12}}>
            <div style={{width:34,height:34,borderRadius:'50%',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}><AppMark size={34}/></div>
            <div style={{flex:1}}><div className="eye" style={{color:R2}}>Coach</div><div style={{fontSize:12.5,marginTop:3,lineHeight:1.4}}>Plus que <b style={{color:CYAN}}>{remain} km</b> pour boucler Courir. Une sortie footing ce soir ?</div></div>
          </div>
        ) : (
          <div style={{marginTop:12,textAlign:'center',background:'radial-gradient(90% 100% at 50% 0%,rgba(255,15,91,.2),transparent)',borderRadius:18,padding:18}}>
            <div className="b" style={{fontSize:26}}>JOURNÉE BOUCLÉE</div>
            <div style={{fontSize:12,color:'var(--t2)',marginTop:6}}>Les 3 anneaux fermés 👏 +120 XP</div>
          </div>
        )}
      </div>
    </div>
  );
}

/* ---------- LIVE RUN ---------- */
function LiveScreen(){
  const c=React.useContext(Ctx), L=c.live;
  return (
    <div className="scan" style={{padding:0,overflow:'hidden',background:'#0A0A0E'}}>
      {/* map */}
      <div style={{position:'absolute',top:0,left:0,right:0,bottom:'44%',background:'linear-gradient(180deg,#12121A,#0E0E14)'}}>
        <div className="gg"></div>
        <svg width="100%" height="100%" viewBox="0 0 360 380" preserveAspectRatio="xMidYMid slice" style={{position:'absolute',inset:0}}>
          <path d="M60 340 C 40 250, 120 240, 140 200 S 120 120, 180 100 S 300 120, 300 60" fill="none" stroke={R} strokeWidth="14" strokeLinecap="round" opacity=".18"/>
          <path d="M60 340 C 40 250, 120 240, 140 200 S 120 120, 180 100 S 300 120, 300 60" fill="none" stroke={R} strokeWidth="5" strokeLinecap="round"/>
          <circle cx="60" cy="340" r="6" fill="#fff"/>
          <circle cx="180" cy="100" r="18" fill={R} opacity=".2" className="pulse"/>
          <circle cx="180" cy="100" r="9" fill={R} stroke="#fff" strokeWidth="3"/>
        </svg>
        <div style={{position:'absolute',top:44,left:18,right:18,display:'flex',justifyContent:'space-between',alignItems:'center'}}>
          <div style={{display:'flex',alignItems:'center',gap:8}}>
            <button className="press" onClick={()=>c.go('prog')} style={{width:34,height:34,borderRadius:'50%',background:'rgba(0,0,0,.45)',backdropFilter:'blur(10px)',display:'flex',alignItems:'center',justifyContent:'center',fontSize:18,color:'#fff'}}>‹</button>
            <div style={{display:'inline-flex',alignItems:'center',gap:6,padding:'7px 12px',borderRadius:99,background:'rgba(255,15,91,.16)',backdropFilter:'blur(10px)'}}>
              <span className="pulse" style={{width:6,height:6,borderRadius:'50%',background:R,boxShadow:`0 0 10px ${R}`}}></span>
              <span className="b" style={{fontSize:11,letterSpacing:2,color:R2}}>{L.paused?'EN PAUSE':'EN DIRECT'}</span>
            </div>
          </div>
          <div className="b" style={{padding:'7px 12px',borderRadius:99,background:'rgba(0,0,0,.4)',backdropFilter:'blur(10px)'}}>Interv. {L.interval}/6</div>
        </div>
        {L.gpsIssue && (
          <div className="rise" style={{position:'absolute',top:88,left:18,right:18,display:'flex',alignItems:'center',gap:8,background:'rgba(255,176,61,.16)',border:'.5px solid rgba(255,176,61,.4)',borderRadius:14,padding:'9px 12px',backdropFilter:'blur(10px)'}}>
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#FFB03D" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" style={{flexShrink:0}}><path d="M12 9v4M12 17h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/></svg>
            <span style={{fontSize:11.5,color:'#FFD79A',fontWeight:600}}>Signal GPS instable — position estimée</span>
          </div>
        )}
      </div>
      {/* coach bubble */}
      {L.coach && <div className="rise" style={{position:'absolute',top:'31%',left:16,right:16,background:'rgba(14,14,20,.85)',backdropFilter:'blur(16px)',border:'.5px solid rgba(255,15,91,.25)',borderRadius:18,padding:'13px 14px',display:'flex',alignItems:'center',gap:12,zIndex:5}}>
        <div style={{width:34,height:34,borderRadius:'50%',background:R,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>🔊</div>
        <div style={{flex:1}}><div className="eye" style={{color:R2}}>Coach · en direct</div><div style={{fontSize:12.5,marginTop:3,lineHeight:1.4}}>{L.coach}</div></div>
      </div>}
      {/* metrics panel */}
      <div style={{position:'absolute',bottom:0,left:0,right:0,height:'44%',background:'linear-gradient(180deg,rgba(14,14,20,.6),#0E0E14 30%)',borderRadius:'26px 26px 0 0',borderTop:'.5px solid var(--line)',padding:'18px 20px 16px'}}>
        <div style={{textAlign:'center',marginBottom:14}}>
          <div className="b" style={{fontSize:64,lineHeight:.8}}>{fmt(L.t)}</div>
          <div className="eye" style={{color:'var(--t2)',marginTop:4}}>Temps · {L.dist.toFixed(2)} km</div>
        </div>
        <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:10,textAlign:'center',marginBottom:14}}>
          {[[L.pace,'ALLURE',R2],[L.hr,'FC · Z4',R],[L.kcal,'KCAL',CYAN]].map(([v,l,col])=>(
            <div key={l}><div className="b" style={{fontSize:26,color:col}}>{v}</div><div className="l" style={{fontSize:8,letterSpacing:1.5,textTransform:'uppercase',color:'var(--t2)',fontWeight:700,marginTop:2}}>{l}</div></div>))}
        </div>
        <div style={{display:'flex',alignItems:'center',justifyContent:'center',gap:16}}>
          <button className="press" onClick={c.stopRun} style={{width:52,height:52,borderRadius:'50%',background:'rgba(255,255,255,.08)',display:'flex',alignItems:'center',justifyContent:'center',fontSize:11,letterSpacing:1}} ><span className="b" style={{color:'#fff'}}>STOP</span></button>
          <button className="press" onClick={c.togglePause} style={{width:70,height:70,borderRadius:'50%',background:'#fff',display:'flex',alignItems:'center',justifyContent:'center',color:'#0A0A0A',fontSize:22}}>{L.paused?'▶':'❚❚'}</button>
          <div style={{width:52,height:52,borderRadius:'50%',background:'rgba(255,15,91,.15)',border:'.5px solid rgba(255,15,91,.3)',display:'flex',alignItems:'center',justifyContent:'center',fontSize:16,color:R2}}>🔒</div>
        </div>
      </div>
    </div>
  );
}

/* ---------- RECAP + DEBRIEF ---------- */
function RecapScreen(){
  const c=React.useContext(Ctx), run=c.store.lastRun;
  const [debrief,setDebrief]=React.useState(false);
  const [rpe,setRpe]=React.useState(2);
  if(!run) return null;
  const rpeOpts=[['😮‍💨','Trop dur'],['😤','Dur'],['🙂','Juste bien'],['😎','Facile']];
  const impacts=[['📈',`Tu progresses vite → prochain intervalle : `,'7×800'],['🛌','Demain = ','récup active 30′']];
  return (
    <div className="scan fade" style={{padding:0}}>
      <div style={{height:190,position:'relative',background:'linear-gradient(180deg,#12121A,#0E0E14)',overflow:'hidden'}}>
        <div className="gg"></div>
        <svg width="100%" height="190" viewBox="0 0 380 190" preserveAspectRatio="xMidYMid slice" style={{position:'absolute',inset:0}}>
          <path d="M40 150 C 30 100, 110 110, 130 80 S 110 30, 180 30 S 300 60, 340 25" fill="none" stroke={R} strokeWidth="4" strokeLinecap="round"/>
          <circle cx="40" cy="150" r="5" fill="#fff"/><circle cx="340" cy="25" r="5" fill={R}/>
        </svg>
        <div style={{position:'absolute',inset:0,background:'linear-gradient(180deg,transparent 40%,#0E0E14)'}}></div>
        <button className="press" onClick={()=>c.go('prog')} style={{position:'absolute',top:44,left:16,width:34,height:34,borderRadius:'50%',background:'rgba(0,0,0,.45)',backdropFilter:'blur(10px)',display:'flex',alignItems:'center',justifyContent:'center',fontSize:20,color:'#fff'}}>‹</button>
        <div style={{position:'absolute',bottom:14,left:18}}><div className="eye" style={{color:LIME}}>✓ Séance terminée</div><div className="b" style={{fontSize:26,marginTop:2}}>{run.title}</div></div>
      </div>
      <div className="pad">
        <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:8}}>
          {[[run.dist.toFixed(2),'KM'],[fmt(run.t),'TEMPS'],[run.avgPace,'ALLURE MOY']].map(([v,l])=>(
            <div key={l} className="card" style={{padding:'12px 10px',textAlign:'center',borderRadius:14}}><div className="b" style={{fontSize:24}}>{v}</div><div className="l" style={{fontSize:8,letterSpacing:1.5,color:'var(--t2)',fontWeight:700,marginTop:3}}>{l}</div></div>))}
        </div>
        <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:8,marginTop:8}}>
          {[[run.avgHr,'FC MOY',R],[run.kcal,'KCAL',CYAN],['+64','D+ (m)',LIME]].map(([v,l,col])=>(
            <div key={l} className="card" style={{padding:'12px 10px',textAlign:'center',borderRadius:14}}><div className="b" style={{fontSize:24,color:col}}>{v}</div><div className="l" style={{fontSize:8,letterSpacing:1.5,color:'var(--t2)',fontWeight:700,marginTop:3}}>{l}</div></div>))}
        </div>
        <div className="eye" style={{color:'var(--t3)',margin:'18px 2px 10px'}}>Splits par km</div>
        <div style={{display:'flex',flexDirection:'column',gap:5}}>
          {run.splits.map((t,i)=>{const best=t===Math.min(...run.splits.map(x=>parseFloat(x.replace(':','.'))))?false:false;return (
            <div key={i} style={{display:'flex',alignItems:'center',gap:12}}>
              <span className="m" style={{fontSize:11,color:'var(--t2)',width:16}}>{i+1}</span>
              <div style={{flex:1,height:22,borderRadius:6,background:'rgba(255,255,255,.05)',position:'relative',overflow:'hidden'}}><div style={{position:'absolute',inset:0,width:`${45+i*7}%`,background:i===run.splits.length-1?R:'rgba(255,255,255,.14)',borderRadius:6}}></div></div>
              <span className="b" style={{fontSize:14,color:i===run.splits.length-1?R2:'#fff',width:38,textAlign:'right'}}>{t}</span>
            </div>);})}
        </div>
        <button className="b btn-rose press" style={{marginTop:18}} onClick={()=>setDebrief(true)}>DONNER MON RESSENTI</button>
        <div style={{height:20}}></div>
      </div>

      {debrief && (
        <div className="sheet-wrap">
          <div className="sheet-bg" onClick={()=>setDebrief(false)}></div>
          <div className="sheet">
            <div className="handle"></div>
            <div className="pad" style={{padding:'8px 18px 24px'}}>
              <div className="eye" style={{color:R,marginTop:8}}>Bilan · {run.title}</div>
              <div className="b" style={{fontSize:24,marginTop:4}}>Comment tu te sens ?</div>
              <div style={{background:'rgba(255,255,255,.06)',border:'.5px solid var(--line)',borderRadius:'4px 16px 16px 16px',padding:'13px 14px',fontSize:13,lineHeight:1.5,display:'flex',gap:10,marginTop:14}}>
                <AppMark size={18} radius={9}/><div>Séance solide 💪 Ton dernier bloc était ton plus rapide — tu avais encore du jus. FC maîtrisée en Z4.</div>
              </div>
              <div className="eye" style={{color:'var(--t3)',margin:'18px 2px 10px'}}>L'effort ressenti</div>
              <div style={{display:'flex',gap:6}}>
                {rpeOpts.map(([e,l],i)=>(
                  <button key={i} className="press" onClick={()=>setRpe(i)} style={{flex:1,textAlign:'center',padding:'12px 4px',borderRadius:14,background:rpe===i?'rgba(255,15,91,.12)':'var(--card)',border:`.5px solid ${rpe===i?'rgba(255,15,91,.35)':'var(--line)'}`}}>
                    <div style={{fontSize:22}}>{e}</div><div style={{fontSize:9,color:rpe===i?R2:'var(--t2)',marginTop:5,fontWeight:600}}>{l}</div></button>))}
              </div>
              <div style={{marginTop:16,background:'linear-gradient(160deg,#20101C,#0E0E14)',border:'.5px solid rgba(255,15,91,.22)',borderRadius:18,padding:16}}>
                <div className="eye" style={{color:R2}}>Impact sur ton programme</div>
                {impacts.map(([e,txt,strong],i)=>(
                  <div key={i} style={{display:'flex',alignItems:'center',gap:12,marginTop:12,paddingBottom:i===0?12:0,borderBottom:i===0?'.5px solid var(--line)':'none'}}>
                    <span style={{fontSize:18}}>{e}</span><div style={{flex:1,fontSize:12.5,lineHeight:1.4,color:'rgba(255,255,255,.75)'}}>{txt}<b style={{color:i===0?'#fff':CYAN}}>{strong}</b>.</div></div>))}
              </div>
              <button className="b btn-rose press" style={{marginTop:16}} onClick={()=>c.finishDebrief(rpe)}>VALIDER &amp; METTRE À JOUR</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

Object.assign(window,{fmt,fmtH,ProgScreen,PlanScreen,RingsScreen,LiveScreen,RecapScreen});
