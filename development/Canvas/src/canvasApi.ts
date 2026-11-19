export async function canvasBridge(
  method: string,
  args: Record<string, unknown> = {},
) {
  if (!window.flutter_inappwebview)
    await new Promise<void>((resolve) =>
      window.addEventListener(
        "flutterInAppWebViewPlatformReady",
        () => resolve(),
        { once: true },
      ),
    );
  const result = await window.flutter_inappwebview!.callHandler(
    "canvas",
    method,
    args,
  );
  if (result?.error) throw new Error(result.error);
  return result;
}
const coverCache = new Map<number, string>();
export const cachedFolderCover=(id:number)=>coverCache.get(id)||'';
type CoverJob={id:number;cancelled:boolean;started:boolean;promise:Promise<string>;resolve:(s:string)=>void;reject:(e:Error)=>void};
const pendingCovers=new Map<number,CoverJob>(),queue:CoverJob[]=[];
let running=0;
const abortError=()=>new DOMException('Inactive screen','AbortError');
function pump(){
 while(running<2&&queue.length){
  const job=queue.shift()!;if(job.cancelled)continue;job.started=true;running++;
  canvasBridge('folderCover',{id:job.id}).then(data=>{
    if(job.cancelled)return;
    coverCache.set(job.id,data.cover||'');if(coverCache.size>256)coverCache.delete(coverCache.keys().next().value!);
    job.resolve(data.cover||'');
  }).catch(e=>{if(!job.cancelled)job.reject(e)}).finally(()=>{running--;if(pendingCovers.get(job.id)===job)pendingCovers.delete(job.id);pump()});
 }
}
export function folderCover(id:number,signal?:AbortSignal):Promise<string>{
 if(signal?.aborted)return Promise.reject(abortError());
 if(coverCache.has(id))return Promise.resolve(coverCache.get(id)!);
 let job=pendingCovers.get(id);
 if(!job){let resolve!:(s:string)=>void,reject!:(e:Error)=>void;const promise=new Promise<string>((r,j)=>{resolve=r;reject=j});
 job={id,cancelled:false,started:false,promise,resolve,reject};pendingCovers.set(id,job);queue.push(job);pump();}
 const current=job;
 const cancel=()=>{if(current.cancelled)return;current.cancelled=true;current.reject(abortError());
   if(pendingCovers.get(id)===current)pendingCovers.delete(id);
   const i=queue.indexOf(current);if(i>=0)queue.splice(i,1);
   if(current.started)void canvasBridge('cancelCover',{id}).catch(()=>{});
 };
 signal?.addEventListener('abort',cancel,{once:true});
 return current.promise.finally(()=>signal?.removeEventListener('abort',cancel));
}
export function clearCoverCache(){
 coverCache.clear();for(const job of pendingCovers.values()){job.cancelled=true;job.reject(abortError());if(job.started)void canvasBridge('cancelCover',{id:job.id}).catch(()=>{})}
 pendingCovers.clear();queue.length=0;
}
