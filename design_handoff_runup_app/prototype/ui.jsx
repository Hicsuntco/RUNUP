/* ═══ RUNUP 4.0 — shared UI ═══ */
const R='#FF0F5B', R2='#FF4D7D', VIO='#7C5CFF', LIME='#C8FF3D', CYAN='#38E0D0';
const Ctx = React.createContext(null);

function StatusBar(){
  return (
    <div className="sb">
      <span className="m">9:41</span>
      <div className="r">
        <svg viewBox="0 0 24 24" fill="#fff"><path d="M2 17h2v-4H2v4zm4 0h2V9H6v8zm4 0h2V5h-2v12zm4 0h2v-6h-2v6zm4 0h2V7h-2v10z"/></svg>
        <svg viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2"><path d="M5 12.5a11 11 0 0 1 14 0M8.5 16a6 6 0 0 1 7 0M12 19h.01"/></svg>
        <svg viewBox="0 0 26 24" fill="none" stroke="#fff" strokeWidth="1.6"><rect x="1" y="7" width="19" height="11" rx="3"/><rect x="3" y="9" width="13" height="7" rx="1.5" fill="#fff"/><path d="M22 11v5" strokeWidth="2.4"/></svg>
      </div>
    </div>
  );
}

/* single progress ring */
function Ring({pct,color,size=96,sw=6,children}){
  const r=size/2-sw/2, c=2*Math.PI*r, off=c*(1-Math.min(pct,100)/100);
  return (
    <div style={{position:'relative',display:'flex',alignItems:'center',justifyContent:'center',width:size,height:size}}>
      <svg className="ring" width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke="rgba(255,255,255,.09)" strokeWidth={sw}/>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round"
          strokeDasharray={c} strokeDashoffset={off} style={{transition:'stroke-dashoffset 1s cubic-bezier(.2,.7,.2,1)'}}/>
      </svg>
      <div style={{position:'absolute'}}>{children}</div>
    </div>
  );
}

/* three concentric activity rings */
function Rings3({vals,size=200,sw=16,gap=5,children}){
  const cols=[R,LIME,CYAN];
  return (
    <div style={{position:'relative',display:'flex',alignItems:'center',justifyContent:'center',width:size,height:size}}>
      <svg className="ring" width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        {vals.map((pct,i)=>{
          const r=size/2-sw/2-i*(sw+gap), c=2*Math.PI*r, off=c*(1-Math.min(pct,100)/100);
          return (<g key={i}>
            <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={cols[i]} strokeWidth={sw} opacity=".16"/>
            <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={cols[i]} strokeWidth={sw} strokeLinecap="round"
              strokeDasharray={c} strokeDashoffset={off} style={{transition:'stroke-dashoffset 1.1s cubic-bezier(.2,.7,.2,1)'}}/>
          </g>);
        })}
      </svg>
      <div style={{position:'absolute'}}>{children}</div>
    </div>
  );
}

const TAB_ICONS={
  prog:'M4 6h16M4 12h11M4 18h7',
  coach:'M21 11.5a8.38 8.38 0 0 1-9 8.34 8.5 8.5 0 0 1-3.8-.9L3 20l1.06-4.2A8.34 8.34 0 0 1 3 11.5 8.38 8.38 0 0 1 12 3a8.38 8.38 0 0 1 9 8.5z',
  stats:'M5 20v-6M12 20V4M19 20v-9',
  club:'M9 11a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4zM3 20a6 6 0 0 1 12 0M17.5 11a3 3 0 1 0-1-5.8M21 20a5.5 5.5 0 0 0-4-5.3'
};

function TabBar(){
  const {screen,go,startRun}=React.useContext(Ctx);
  const items=[['prog','Prog'],['coach','Coach'],['live',''],['stats','Stats'],['club','Club']];
  return (
    <div style={{position:'absolute',bottom:18,left:'50%',transform:'translateX(-50%)',width:'calc(100% - 34px)',height:64,
      background:'rgba(18,18,26,.72)',backdropFilter:'blur(28px) saturate(1.4)',WebkitBackdropFilter:'blur(28px) saturate(1.4)',
      border:'.5px solid rgba(255,255,255,.09)',borderRadius:24,padding:'0 6px',display:'flex',justifyContent:'space-between',
      alignItems:'center',zIndex:40,boxShadow:'0 16px 44px rgba(0,0,0,.5),inset 0 1px 0 rgba(255,255,255,.06)'}}>
      {items.map(([id,lbl])=>{
        if(id==='live') return (
          <button key="live" className="press" onClick={startRun} style={{flex:'0 0 auto',display:'flex',flexDirection:'column',alignItems:'center',width:60}}>
            <div style={{width:50,height:50,borderRadius:18,background:`linear-gradient(150deg,${R2},${R})`,display:'flex',alignItems:'center',justifyContent:'center',boxShadow:'0 8px 22px rgba(255,15,91,.55)'}}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="#fff"><path d="M8 5v14l11-7z"/></svg>
            </div>
            <span className="b" style={{fontSize:8,letterSpacing:1,color:R2,marginTop:4}}>RUN</span>
          </button>
        );
        const on=screen===id;
        const col=on?R2:'rgba(255,255,255,.4)';
        return (
          <button key={id} className="press" onClick={()=>go(id)} style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:5,height:'100%',position:'relative'}}>
            <svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke={col} strokeWidth={on?2.4:2} strokeLinecap="round" strokeLinejoin="round"><path d={TAB_ICONS[id]}/></svg>
            <span className="b" style={{fontSize:8,letterSpacing:.8,color:col}}>{lbl}</span>
            <span style={{position:'absolute',top:8,width:4,height:4,borderRadius:'50%',background:R,opacity:on?1:0}}></span>
          </button>
        );
      })}
    </div>
  );
}

function Header({eye,title,right}){
  const c=React.useContext(Ctx);
  return (
    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',margin:'2px 0 14px'}}>
      <div>
        <div className="eye" style={{color:R}}>{eye}</div>
        <div className="b" style={{fontSize:24,marginTop:2}}>{title}</div>
      </div>
      {right!==undefined?right:<button className="press" onClick={()=>c&&c.go&&c.go('profile')} title="Profil" style={{width:36,height:36,borderRadius:'50%',background:R,display:'flex',alignItems:'center',justifyContent:'center'}}><span className="b" style={{color:'#fff'}}>{(c&&c.store&&c.store.name||'L')[0]}</span></button>}
    </div>
  );
}

/* app mark — a progress ring with motion notch, ties to the app's core rings metaphor. Avoids emoji + avoids reading as a stripes logo. */
function AppMark({size=24,radius,color='#fff'}){
  const r=radius!==undefined?radius:size*0.3;
  return (
    <div style={{width:size,height:size,borderRadius:r,background:`linear-gradient(135deg,${R},${VIO})`,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
      <svg width={size*0.56} height={size*0.56} viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="12" r="8.4" stroke={color} strokeWidth="3" strokeLinecap="round" strokeDasharray="39.6 13.2" transform="rotate(-90 12 12)"/>
        <circle cx="12" cy="3.6" r="2.1" fill={color}/>
      </svg>
    </div>
  );
}

Object.assign(window,{R,R2,VIO,LIME,CYAN,Ctx,StatusBar,Ring,Rings3,TabBar,Header,AppMark});
