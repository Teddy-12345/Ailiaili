import {useEffect,useRef,useState} from 'react';
import {useScreenActive} from './ScreenActivity';
import {schedulePoster,thumbnailUrl} from '../mediaWork';
const displayed=new Set<string>();
function remember(src:string){displayed.add(src);if(displayed.size>1024)displayed.delete(displayed.values().next().value!)}
export function CachedPoster({src,className='cover canvas-poster',eager=false,children,onError}:{src:string;className?:string;eager?:boolean;children?:React.ReactNode;onError?:()=>void}){
 const url=thumbnailUrl(src),known=displayed.has(url),active=useScreenActive();
 const [loaded,setLoaded]=useState(known),[failed,setFailed]=useState(false),[wanted,setWanted]=useState(eager),[requested,setRequested]=useState(false);
 const root=useRef<HTMLDivElement>(null),activeRef=useRef(active),finish=useRef<(()=>void)|null>(null);
 activeRef.current=active;
 useEffect(()=>{
   if(!active||wanted||!root.current)return;
   const observer=new IntersectionObserver(entries=>{if(entries.some(e=>e.isIntersecting)){setWanted(true);observer.disconnect()}},{root:root.current.closest('.canvas-scroll'),rootMargin:'80px 0px'});
   observer.observe(root.current);return()=>observer.disconnect();
 },[active,wanted]);
 useEffect(()=>{
   if(!active){if(!loaded)setRequested(false);return}
   if((requested&&loaded)||!wanted||!src||failed)return;
   return schedulePoster(done=>{finish.current=done;setRequested(true)});
 },[active,wanted,url,failed]);
 return <div ref={root} className={`${className} ${loaded?'is-loaded is-settled':''}`} data-poster-cached={known}>
   {!loaded&&!failed&&src&&<div className="canvas-skeleton"/>}
   {requested&&src&&!failed&&<img className="poster-image" src={url} alt="" draggable={false} decoding="async" referrerPolicy="no-referrer"
     onLoad={()=>{finish.current?.();finish.current=null;if(!activeRef.current)return;remember(url);setLoaded(true)}}
     onError={()=>{finish.current?.();finish.current=null;if(!activeRef.current)return;setFailed(true);onError?.()}}/>}
   {children}
 </div>;
}
