type Job={start:(done:()=>void)=>void;running:boolean;cancelled:boolean;done:()=>void};
const jobs:Job[]=[];let running=0;
function pump(){while(running<2&&jobs.length){const job=jobs.shift()!;if(job.cancelled)continue;job.running=true;running++;let finished=false;job.done=()=>{if(finished)return;finished=true;running--;pump()};job.start(job.done)}}
export function schedulePoster(start:Job['start']){const job:Job={start,running:false,cancelled:false,done:()=>{}};jobs.push(job);pump();return()=>{job.cancelled=true;if(job.running)job.done();else{const i=jobs.indexOf(job);if(i>=0)jobs.splice(i,1)}}}

// Match the existing native CDN thumbnail convention; never rewrite arbitrary URLs.
export function thumbnailUrl(src:string,avatar=false){
 try{const u=new URL(src);if(!/(^|\.)hdslb\.com$/i.test(u.hostname)||!u.pathname.includes('/bfs/'))return src;
 const path=u.pathname.replace(/@[^/]*$/,'');if(!/\.(jpe?g|png|webp)$/i.test(path))return src;
 u.pathname=path+(avatar?'@160w_160h_1c_80q.webp':'@640w_360h_1c_80q.webp');return u.href;
 }catch{return src}
}
