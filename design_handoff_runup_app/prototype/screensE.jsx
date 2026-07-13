/* ═══ RUNUP 4.0 — screens E : Paywall Premium ═══ */

const PREMIUM_FEATURES=[
  ['Coach IA sans limite','Discussions illimitées, à toute heure, avant et après chaque sortie.'],
  ['Programme qui s\u2019adapte en continu','Ajustements automatiques après chaque séance, chaque ressenti.'],
  ['Stats avancées','VO\u2082max, prédictions de course, analyse de charge sur 12 semaines.'],
  ['Connexions illimitées','Apple Santé, Strava, Garmin synchronisés en temps réel.']
];

function PaywallScreen({onSkip}){
  const c=React.useContext(Ctx);
  const [plan,setPlan]=useState('annual'); // 'monthly' | 'annual'
  const [trial,setTrial]=useState(true);
  const [loading,setLoading]=useState(false);

  function subscribe(){
    setLoading(true);
    setTimeout(()=>{
      setLoading(false);
      c.setPremium(true);
      toast(trial?'Essai gratuit activé · 7 jours':'Abonnement activé — bienvenue dans Premium');
      onSkip();
    },1400);
  }

  return (
    <div style={{position:'absolute',inset:0,display:'flex',flexDirection:'column',background:'radial-gradient(90% 55% at 50% 0%,rgba(124,92,255,.22),transparent 60%),var(--bg)',zIndex:120}}>
      <div className="scan fade" style={{display:'flex',flexDirection:'column',padding:'0 22px'}}>
        <div style={{display:'flex',justifyContent:'flex-end',paddingTop:18}}>
          <button className="press" onClick={onSkip} style={{fontSize:13,color:'var(--t3)',fontWeight:600,padding:'6px 4px'}}>Plus tard</button>
        </div>

        <div style={{textAlign:'center',marginTop:6}}>
          <div style={{display:'inline-flex'}}><AppMark size={64} radius={18}/></div>
          <div className="b" style={{fontSize:30,marginTop:16,lineHeight:.95}}>PASSE EN<br/>PREMIUM</div>
          <div style={{fontSize:13,color:'var(--t2)',marginTop:10,lineHeight:1.5}}>Le coach qui s'adapte vraiment à toi, sans limite.</div>
        </div>

        <div style={{display:'flex',flexDirection:'column',gap:12,marginTop:26}}>
          {PREMIUM_FEATURES.map(([t,d],i)=>(
            <div key={i} style={{display:'flex',gap:12,alignItems:'flex-start'}}>
              <div style={{width:22,height:22,borderRadius:'50%',background:'rgba(124,92,255,.18)',border:'.5px solid rgba(124,92,255,.4)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,marginTop:1}}>
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={VIO} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12l5 5L19 7"/></svg>
              </div>
              <div><div style={{fontSize:13.5,fontWeight:600}}>{t}</div><div style={{fontSize:11.5,color:'var(--t2)',marginTop:2,lineHeight:1.4}}>{d}</div></div>
            </div>))}
        </div>

        <div style={{display:'flex',flexDirection:'column',gap:8,marginTop:26}}>
          <button className="press" onClick={()=>setPlan('annual')}
            style={{position:'relative',display:'flex',justifyContent:'space-between',alignItems:'center',padding:'14px 16px',borderRadius:16,
              background:plan==='annual'?'rgba(124,92,255,.14)':'var(--card)',border:`1.5px solid ${plan==='annual'?VIO:'var(--line)'}`}}>
            <div style={{textAlign:'left'}}><div style={{fontSize:14,fontWeight:700}}>Annuel</div><div style={{fontSize:11,color:'var(--t2)',marginTop:2}}>49,99 € /an · soit 4,17 €/mois</div></div>
            <span className="chip" style={{background:VIO,color:'#fff',fontSize:10}}>-30%</span>
          </button>
          <button className="press" onClick={()=>setPlan('monthly')}
            style={{display:'flex',justifyContent:'space-between',alignItems:'center',padding:'14px 16px',borderRadius:16,
              background:plan==='monthly'?'rgba(124,92,255,.14)':'var(--card)',border:`1.5px solid ${plan==='monthly'?VIO:'var(--line)'}`}}>
            <div style={{textAlign:'left'}}><div style={{fontSize:14,fontWeight:700}}>Mensuel</div><div style={{fontSize:11,color:'var(--t2)',marginTop:2}}>5,99 € /mois · sans engagement</div></div>
          </button>
        </div>

        <button className="press" onClick={()=>setTrial(v=>!v)} style={{display:'flex',alignItems:'center',gap:10,marginTop:14,padding:'2px 2px'}}>
          <span style={{width:20,height:20,borderRadius:6,border:`2px solid ${trial?VIO:'rgba(255,255,255,.25)'}`,background:trial?VIO:'none',display:'flex',alignItems:'center',justifyContent:'center',fontSize:12,color:'#fff',flexShrink:0}}>{trial?'✓':''}</span>
          <span style={{fontSize:12.5,color:'var(--t2)'}}>Commencer par 7 jours d'essai gratuit</span>
        </button>

        <div style={{flex:1,minHeight:14}}></div>
        <button className="b press" disabled={loading} onClick={subscribe}
          style={{background:`linear-gradient(135deg,${VIO},${R})`,color:'#fff',borderRadius:14,padding:15,fontSize:16,marginBottom:10,opacity:loading?.75:1,display:'flex',alignItems:'center',justifyContent:'center',gap:8}}>
          {loading ? <span className="dots"><span></span><span></span><span></span></span> : (trial?"COMMENCER L'ESSAI GRATUIT":`S'ABONNER · ${plan==='annual'?'49,99 €/an':'5,99 €/mois'}`)}
        </button>
        <div style={{textAlign:'center',fontSize:10.5,color:'var(--t3)',marginBottom:20,lineHeight:1.5}}>
          {trial?'Puis '+(plan==='annual'?'49,99 €/an':'5,99 €/mois')+' — annule à tout moment.':'Résiliable à tout moment depuis ton profil.'}
        </div>
      </div>
    </div>
  );
}

Object.assign(window,{PaywallScreen});
