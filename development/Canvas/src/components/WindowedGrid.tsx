import {useLayoutEffect,useRef,useState,type ReactNode} from 'react';
import {useScreenActive} from './ScreenActivity';

// Only visible rows and one neighbouring row own DOM, observers and decoders.
export function WindowedGrid<T>({items,className,renderItem}:{items:T[];className:string;renderItem:(item:T,index:number)=>ReactNode}) {
  const root=useRef<HTMLDivElement>(null),active=useScreenActive();
  const [range,setRange]=useState({start:0,end:24,step:0,columns:2});
  useLayoutEffect(()=>{
    const grid=root.current,scroll=grid?.closest<HTMLElement>('.canvas-scroll');
    if(!active||!grid||!scroll)return;
    let frame=0,step=0,columns=2;
    const update=()=>{
      frame=0;
      const first=grid.querySelector<HTMLElement>('.selection-cell');
      if(!first)return;
      const style=getComputedStyle(grid);
      columns=style.gridTemplateColumns.split(' ').filter(Boolean).length||2;
      step=first.getBoundingClientRect().height+(parseFloat(style.rowGap)||0);
      if(!step)return;
      const origin=grid.getBoundingClientRect().top-scroll.getBoundingClientRect().top+scroll.scrollTop;
      const top=Math.max(0,scroll.scrollTop-origin);
      const firstRow=Math.max(0,Math.floor(top/step)-1);
      const lastRow=Math.ceil((top+scroll.clientHeight)/step)+1;
      const next={start:Math.min(firstRow*columns,Math.max(0,Math.ceil(items.length/columns)-1)*columns),end:Math.min(items.length,lastRow*columns),step,columns};
      setRange(old=>Object.keys(next).every(k=>old[k as keyof typeof old]===next[k as keyof typeof next])?old:next);
    };
    const schedule=()=>{if(!frame)frame=requestAnimationFrame(update)};
    update();const observer=new ResizeObserver(schedule);observer.observe(grid);observer.observe(scroll);
    scroll.addEventListener('scroll',schedule,{passive:true});
    return()=>{if(frame)cancelAnimationFrame(frame);observer.disconnect();scroll.removeEventListener('scroll',schedule)};
  },[active,items.length]);
  const start=range.step?Math.min(range.start,Math.max(0,Math.ceil(items.length/range.columns)-1)*range.columns):0,end=Math.max(start+range.columns,range.end);
  const rows=Math.ceil(items.length/range.columns),endRow=Math.ceil(Math.min(end,items.length)/range.columns);
  return <div ref={root} className={className} data-total-items={items.length}
    style={{paddingTop:Math.floor(start/range.columns)*range.step,paddingBottom:Math.max(0,rows-endRow)*range.step}}>
      {items.slice(start,end).map((item,i)=>renderItem(item,start+i))}
    </div>;
}
