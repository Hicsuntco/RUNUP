/* ═══ RUNUP 4.0 — screens B : Coach IA · Stats · Club · Race ═══ */

/* ---------- COACH (real AI) ---------- */
function CoachScreen(){
  const c=React.useContext(Ctx);
  const {chat,coachTyping,sendCoach,store}=c;
  const [txt,setTxt]=React.useState('');
  const scRef=React.useRef(null);
  React.useEffect(()=>{const el=scRef.current;if(el)el.scrollTop=el.scrollHeight;},[chat,coachTyping]);
  const chips=['Adapte ma semaine','Je suis fatiguée','Conseils nutrition','Analyse ma dernière sortie'];
  const send=(t)=>{const m=(t||txt).trim();if(!m||coachTyping)return;setTxt('');sendCoach(m);};
  const offline=store.coachOffline;
  return (
    <div className="fade" style={{display:'flex',flexDirection:'column',height:'100%'}}>
      <div style={{padding:'6px 18px 10px',display:'flex',alignItems:'center',gap:12,flexShrink:0}}>
        <div style={{width:40,height:40,borderRadius:'50%',display:'flex',alignItems:'center',justifyContent:'center',opacity:offline?.4:1}}><AppMark size={40}/></div>
        <div style={{flex:1}}><div className="b" style={{fontSize:19}}>Ton coach</div>
          <div style={{fontSize:10,color:offline?'#FFB03D':LIME,display:'flex',alignItems:'center',gap:5}}><span style={{width:5,height:5,borderRadius:'50%',background:offline?'#FFB03D':LIME}}></span>{offline?'hors ligne — nouvelle tentative en cours':'en ligne · connaît ton historique'}</div>
        </div>
      </div>
      <div ref={scRef} className="scan" style={{padding:'6px 18px 0',display:'flex',flexDirection:'column',gap:10}}>
        <div style={{textAlign:'center',fontSize:10,color:'var(--t3)',margin:'4px 0'}}>AUJOURD'HUI</div>
        {chat.map((m,i)=> m.role==='error'
          ? <div key={i} className="rise" style={{alignSelf:'stretch',display:'flex',alignItems:'center',gap:10,background:'rgba(255,176,61,.1)',border:'.5px solid rgba(255,176,61,.3)',borderRadius:14,padding:'11px 13px'}}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#FFB03D" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{flexShrink:0}}><path d="M12 9v4M12 17h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/></svg>
              <div style={{flex:1,fontSize:12.5,color:'#FFD79A',lineHeight:1.4}}>{m.text}</div>
              <button className="press b" onClick={()=>send('...')} style={{fontSize:11,color:'#FFB03D',flexShrink:0,padding:'4px 8px'}}>Réessayer</button>
            </div>
          : m.role==='coach'
          ? <div key={i} className="rise" style={{alignSelf:'flex-start',maxWidth:'82%',background:'rgba(255,255,255,.06)',border:'.5px solid var(--line)',borderRadius:'4px 16px 16px 16px',padding:'11px 13px',fontSize:13,lineHeight:1.5,whiteSpace:'pre-wrap'}}>{m.text}</div>
          : <div key={i} className="rise" style={{alignSelf:'flex-end',maxWidth:'80%',background:R,borderRadius:'16px 4px 16px 16px',padding:'11px 13px',fontSize:13,lineHeight:1.45,color:'#fff'}}>{m.text}</div>
        )}
        {coachTyping && <div style={{alignSelf:'flex-start',background:'rgba(255,255,255,.06)',border:'.5px solid var(--line)',borderRadius:'4px 16px 16px 16px',padding:'12px 14px'}} className="dots"><span></span><span></span><span></span></div>}
        <div style={{display:'flex',gap:7,flexWrap:'wrap',margin:'2px 0 4px'}}>
          {chips.map(t=><button key={t} className="press" onClick={()=>send(t)} style={{padding:'6px 11px',borderRadius:99,background:'var(--card)',border:'.5px solid var(--line)',color:'rgba(255,255,255,.7)',fontSize:11,fontWeight:600}}>{t}</button>)}
        </div>
      </div>
      <div style={{padding:'8px 16px 96px',flexShrink:0}}>
        <div style={{display:'flex',alignItems:'center',gap:10,background:'rgba(255,255,255,.06)',border:'.5px solid var(--line)',borderRadius:99,padding:'8px 8px 8px 16px'}}>
          <input value={txt} onChange={e=>setTxt(e.target.value)} onKeyDown={e=>e.key==='Enter'&&send()} placeholder="Écris à ton coach…" style={{flex:1,background:'none',border:'none',outline:'none',color:'#fff',fontSize:13,fontFamily:'inherit'}}/>
          <button className="press" onClick={()=>send()} style={{width:34,height:34,borderRadius:'50%',background:R,display:'flex',alignItems:'center',justifyContent:'center',fontSize:15,flexShrink:0}}>↑</button>
        </div>
      </div>
    </div>
  );
}

/* ---------- STATS ---------- */
function StatsScreen(){
  const c=React.useContext(Ctx), s=c.store;
  const bars=[40,55,48,70,62,80,58,90,75,100,88];
  return (
    <div className="scan fade" style={{paddingBottom:120}}>
      <div className="pad" style={{paddingTop:8}}>
        <Header eye="Analyse · progression" title="Ta forme monte" right={
          <button className="press" onClick={()=>c.go('history')} style={{fontSize:11,color:'var(--t2)',fontWeight:600,display:'flex',alignItems:'center',gap:5,padding:'8px 12px',borderRadius:99,background:'var(--card)',border:'.5px solid var(--line)'}}>Historique ›</button>
        }/>
        <div className="card" style={{padding:16,marginBottom:10}}>
          <div className="eye" style={{color:'var(--t2)'}}>VO₂ max estimé</div>
          <div style={{display:'flex',alignItems:'baseline',gap:6,marginTop:6}}><span className="b" style={{fontSize:52,lineHeight:.8}}>52.4</span><span className="chip" style={{background:'rgba(200,255,61,.14)',color:LIME}}>▲ +2.1</span></div>
          <div style={{fontSize:11,color:'var(--t2)',marginTop:6}}>Top 12% · femmes 25-34 ans</div>
          <svg width="100%" height="70" viewBox="0 0 300 70" style={{marginTop:8}} preserveAspectRatio="none">
            <defs><linearGradient id="vg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={R} stopOpacity=".35"/><stop offset="1" stopColor={R} stopOpacity="0"/></linearGradient></defs>
            <polygon points="0,58 40,54 80,50 120,44 160,40 200,32 240,26 300,14 300,70 0,70" fill="url(#vg)"/>
            <polyline points="0,58 40,54 80,50 120,44 160,40 200,32 240,26 300,14" fill="none" stroke={R} strokeWidth="2.5"/>
          </svg>
        </div>
        <div style={{background:'linear-gradient(160deg,#20101C,#0E0E14)',border:'.5px solid rgba(255,15,91,.2)',borderRadius:20,padding:16,marginBottom:10}}>
          <div className="eye" style={{color:R2}}>Prédiction de course</div>
          <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:8,marginTop:12}}>
            {[['5 KM','22:40'],['10 KM','47:10'],['SEMI','1:45']].map(([d,t],i)=>(
              <div key={d} style={{textAlign:'center',padding:'10px 4px',borderRadius:12,background:i===1?'rgba(255,15,91,.14)':'var(--card)',border:`.5px solid ${i===1?'rgba(255,15,91,.3)':'var(--line)'}`}}><div className="l" style={{fontSize:8,letterSpacing:1.5,color:'var(--t2)',fontWeight:700}}>{d}</div><div className="b" style={{fontSize:22,marginTop:4,color:i===1?R2:'#fff'}}>{t}</div></div>))}
          </div>
          <div style={{fontSize:11,color:'var(--t2)',marginTop:10,lineHeight:1.4}}>Objectif {s.goal} → <b style={{color:LIME}}>en avance de 20″</b> sur ton plan.</div>
        </div>
        <div className="card" style={{padding:16}}>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:12}}>
            <div className="eye" style={{color:'var(--t2)'}}>Charge · 11 sem.</div><span className="chip" style={{background:'rgba(56,224,208,.12)',color:CYAN}}>Zone optimale</span>
          </div>
          <div style={{display:'flex',alignItems:'flex-end',gap:5,height:70}}>
            {bars.map((h,i)=><div key={i} style={{flex:1,height:`${h}%`,borderRadius:4,background:i>=bars.length-2?R:'rgba(255,255,255,.14)'}}></div>)}
          </div>
          <div style={{display:'flex',justifyContent:'space-between',marginTop:8,fontSize:10,color:'var(--t3)'}}><span>S1</span><span>ratio charge 1.1</span><span>S11</span></div>
        </div>
      </div>
    </div>
  );
}

/* ---------- CLUB ---------- */
const FEED=[
  {name:'Sarah K.',ini:'S',time:'il y a 20 min',text:'a couru 8.2 km · Sortie longue',kudos:6,col:R},
  {name:'Thomas R.',ini:'T',time:'il y a 2 h',text:'a débloqué le badge 🏔 Dénivelé',kudos:14,col:VIO},
  {name:'Marc D.',ini:'M',time:'ce matin',text:'a couru 5.0 km · Récup active',kudos:3,col:CYAN},
  {name:'Sarah K.',ini:'S',time:'hier',text:'a rejoint le défi 100 km en juillet',kudos:9,col:R}
];

function ClubScreen(){
  const c=React.useContext(Ctx), s=c.store;
  const [tab,setTab]=React.useState('board');
  const [kudos,setKudos]=React.useState({});
  const board=[['1','Thomas R.','2 480','🥇'],['2',`${s.name} M. · toi`,(2000+s.xp).toLocaleString('fr-FR'),'🥈',true],['3','Sarah K.','2 180','🥉'],['4','Marc D.','1 950','']];
  const badges=[['🔥','Série '+s.streak+'j',true],['⚡','VMA pro',true],['🌅','Lève-tôt',true],['🏔','Dénivelé',false]];
  return (
    <div className="scan fade" style={{paddingBottom:120}}>
      <div className="pad" style={{paddingTop:8}}>
        <Header eye="Le Club" title="Runners du 11e" right={<span className="chip" style={{background:'var(--card)',color:'rgba(255,255,255,.7)'}}>248 membres</span>}/>
        <div style={{background:'linear-gradient(135deg,#241046,#160B1F)',border:'.5px solid rgba(124,92,255,.3)',borderRadius:20,padding:16,marginBottom:10}}>
          <div style={{display:'flex',alignItems:'center',gap:14}}>
            <div className="b" style={{width:52,height:52,borderRadius:16,background:`linear-gradient(135deg,${VIO},${R})`,display:'flex',alignItems:'center',justifyContent:'center',fontSize:22}}>12</div>
            <div style={{flex:1}}>
              <div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline'}}><span className="b" style={{fontSize:16}}>Niveau 12 · Foulée d'or</span><span className="m" style={{fontSize:10,color:'var(--t2)'}}>{(2000+s.xp).toLocaleString('fr-FR')} / 2 800 XP</span></div>
              <div className="bar" style={{marginTop:8}}><i style={{width:`${Math.min((2000+s.xp)/2800*100,100)}%`,background:`linear-gradient(90deg,${VIO},${R})`}}></i></div>
            </div>
          </div>
        </div>
        <div className="card" style={{padding:16,marginBottom:14}}>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:10}}><div className="eye" style={{color:R2}}>Défi du mois</div><span className="chip" style={{background:'rgba(255,15,91,.14)',color:R2}}>J-9</span></div>
          <div className="b" style={{fontSize:19}}>100 km en juillet</div>
          <div className="bar" style={{marginTop:10}}><i style={{width:`${Math.min((71+s.rings.run.v-7.2)/100*100,100)}%`,background:R}}></i></div>
          <div style={{display:'flex',justifyContent:'space-between',marginTop:7,fontSize:11,color:'var(--t2)'}}><span>{(71+Math.max(0,s.rings.run.v-7.2)).toFixed(0)} km parcourus</span><span>ce mois-ci</span></div>
        </div>

        <div style={{display:'flex',gap:4,background:'rgba(255,255,255,.05)',border:'.5px solid var(--line)',borderRadius:14,padding:3,marginBottom:14}}>
          {[['board','Classement'],['feed','Fil d\'activité']].map(([id,l])=>(
            <button key={id} className="press" onClick={()=>setTab(id)} style={{flex:1,padding:'9px 4px',borderRadius:11,background:tab===id?R:'none',color:'#fff',fontSize:12.5,fontWeight:600}}>{l}</button>))}
        </div>

        {tab==='board' ? (
          <React.Fragment>
            <div style={{display:'flex',flexDirection:'column',gap:6,marginBottom:14}}>
              {board.map(([rk,name,xp,medal,me])=>(
                <div key={rk} style={{display:'flex',alignItems:'center',gap:12,padding:'11px 13px',borderRadius:14,background:me?'rgba(255,15,91,.1)':'var(--card2)',border:`.5px solid ${me?'rgba(255,15,91,.28)':'var(--line)'}`}}>
                  <span className="b" style={{fontSize:15,width:20,color:me?R2:'var(--t2)'}}>{medal||rk}</span>
                  <span style={{flex:1,fontSize:13,fontWeight:me?600:400}}>{name}</span>
                  <span className="b" style={{fontSize:15,color:me?R2:'#fff'}}>{xp}</span>
                </div>))}
            </div>
            <div className="eye" style={{color:'var(--t3)',margin:'4px 2px 10px'}}>Derniers badges</div>
            <div style={{display:'flex',gap:10}}>
              {badges.map(([e,n,on],i)=>(
                <div key={i} style={{flex:1,textAlign:'center'}}><div style={{width:'100%',aspectRatio:'1',borderRadius:16,background:on?'var(--card)':'rgba(255,255,255,.02)',border:'.5px solid var(--line)',display:'flex',alignItems:'center',justifyContent:'center',fontSize:26,opacity:on?1:.35}}>{e}</div><div style={{fontSize:8,color:'var(--t2)',marginTop:5,fontWeight:600}}>{n}</div></div>))}
            </div>
          </React.Fragment>
        ) : (
          <div style={{display:'flex',flexDirection:'column',gap:8}}>
            {FEED.map((f,i)=>(
              <div key={i} className="card" style={{padding:'13px 14px'}}>
                <div style={{display:'flex',alignItems:'center',gap:10}}>
                  <div style={{width:34,height:34,borderRadius:'50%',background:f.col,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}><span className="b" style={{fontSize:13,color:'#fff'}}>{f.ini}</span></div>
                  <div style={{flex:1}}>
                    <div style={{fontSize:13}}><b style={{fontWeight:600}}>{f.name}</b> {f.text}</div>
                    <div style={{fontSize:10,color:'var(--t3)',marginTop:2}}>{f.time}</div>
                  </div>
                </div>
                <button className="press" onClick={()=>setKudos(k=>({...k,[i]:!k[i]}))}
                  style={{marginTop:10,display:'flex',alignItems:'center',gap:6,padding:'6px 12px',borderRadius:99,background:kudos[i]?'rgba(255,15,91,.16)':'var(--card2)',border:`.5px solid ${kudos[i]?'rgba(255,15,91,.35)':'var(--line)'}`,color:kudos[i]?R2:'var(--t2)',fontSize:11.5,fontWeight:600}}>
                  <span>👏</span>{f.kudos+(kudos[i]?1:0)}
                </button>
              </div>))}
          </div>
        )}
      </div>
    </div>
  );
}

/* ---------- RACE objective ---------- */
function RaceScreen(){
  const c=React.useContext(Ctx), s=c.store;
  const plan=[['1-3 km','Départ contrôlé','4:52'],['4-8 km','Rythme cible','4:45'],['9 km','Relance','4:40'],['10 km','Sprint final','4:20']];
  return (
    <div className="scan fade" style={{paddingBottom:120}}>
      <div className="pad" style={{paddingTop:8}}>
        <div style={{display:'flex',alignItems:'center',gap:12,margin:'2px 0 6px'}}>
          <button className="press" onClick={()=>c.go('prog')} style={{fontSize:22,color:'var(--t2)'}}>‹</button>
          <div style={{textAlign:'left'}}><div className="eye" style={{color:R}}>Ton objectif</div><div className="b" style={{fontSize:24}}>{s.goal.includes('·')?s.goal.split('·')[0].trim():s.goal}</div></div>
        </div>
        <div style={{fontSize:12,color:'var(--t2)',margin:'0 0 4px 34px'}}>{s.raceDate?new Date(s.raceDate+'T09:00').toLocaleDateString('fr-FR',{weekday:'long',day:'numeric',month:'long'}):'Dimanche 16 ao\u00fbt'} · 09:00</div>
        <div style={{display:'flex',justifyContent:'center',gap:10,margin:'16px 0'}}>
          {[[s.raceIn,'JOURS'],[s.goal.includes('·')?s.goal.split('·')[1].trim():s.goal,'OBJECTIF'],['4:45','ALLURE']].map(([v,l],i)=>(
            <div key={l} style={{flex:1,textAlign:'center',background:i===0?'rgba(255,15,91,.12)':'var(--card)',border:`.5px solid ${i===0?'rgba(255,15,91,.3)':'var(--line)'}`,borderRadius:16,padding:'16px 6px'}}><div className="b" style={{fontSize:30,color:i===0?R2:'#fff'}}>{v}</div><div className="l" style={{fontSize:8,letterSpacing:1.5,color:'var(--t2)',fontWeight:700,marginTop:4}}>{l}</div></div>))}
        </div>
        <div className="card" style={{padding:'14px 16px',marginBottom:10}}>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}><span className="eye" style={{color:'var(--t2)'}}>Préparation</span><span className="chip" style={{background:'rgba(200,255,61,.12)',color:LIME}}>Dans les temps</span></div>
          <div className="bar" style={{marginTop:10,height:8}}><i style={{width:'68%',background:`linear-gradient(90deg,${R},${LIME})`}}></i></div>
          <div style={{display:'flex',justifyContent:'space-between',marginTop:7,fontSize:10,color:'var(--t2)'}}><span>Base ✓</span><span>Spécifique ●</span><span>Affûtage</span></div>
        </div>
        <div className="eye" style={{color:'var(--t3)',margin:'16px 2px 10px'}}>Stratégie d'allure · jour J</div>
        <div style={{display:'flex',flexDirection:'column',gap:6}}>
          {plan.map(([km,t,pace],i)=>(
            <div key={i} style={{display:'flex',alignItems:'center',gap:12,background:'var(--card2)',border:'.5px solid var(--line)',borderRadius:14,padding:'12px 14px'}}>
              <div style={{width:3,height:30,borderRadius:2,background:i===3?R:'rgba(255,255,255,.2)'}}></div>
              <div style={{flex:1}}><div style={{fontSize:13,fontWeight:600}}>{t}</div><div style={{fontSize:10,color:'var(--t2)',marginTop:1}}>{km}</div></div>
              <div className="b" style={{fontSize:18,color:i===3?R2:'#fff'}}>{pace}<small style={{fontSize:9,color:'var(--t2)'}}> /km</small></div>
            </div>))}
        </div>
      </div>
    </div>
  );
}

Object.assign(window,{CoachScreen,StatsScreen,ClubScreen,RaceScreen});
