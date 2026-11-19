/* 指尖滑过选项时只预览，松手选中；不改变按钮本身为滑块。 */
import {useRef,type PointerEvent} from 'react';
export function useTouchChoice(selector:string,onChoose:(el:HTMLElement)=>void){
 const drag=useRef<{id:number;target:HTMLElement|null;root:HTMLElement}|null>(null);
 const suppress=useRef(false);
 const mark=(root:HTMLElement,x:number,y:number)=>{
  const bounds=root.getBoundingClientRect();
  const candidates=Array.from(root.querySelectorAll<HTMLElement>(selector)).filter(el=>!el.hasAttribute('disabled'));
  const previous=drag.current?.target;
  let target:HTMLElement|null=null;
  if(x>=bounds.left-12&&x<=bounds.right+12&&y>=bounds.top&&y<=bounds.bottom){
    const direct=candidates.find(el=>{const r=el.getBoundingClientRect();return y>=r.top&&y<=r.bottom});
    if(direct){
      const r=direct.getBoundingClientRect();
      target=previous&&previous!==direct&&(y<r.top+4||y>r.bottom-4)?previous:direct;
    }else target=previous||null;
  }
  if(target===previous&&root.querySelector('[data-touch-hover]')===target)return target;
  root.querySelectorAll('[data-touch-hover]').forEach(e=>e.removeAttribute('data-touch-hover'));
  target?.setAttribute('data-touch-hover','true');return target;
 };
 const end=(e:PointerEvent<HTMLElement>,cancel=false)=>{
  const d=drag.current;if(!d || e.pointerId!==d.id)return;drag.current=null;
  d.root.querySelectorAll('[data-touch-hover]').forEach(el=>el.removeAttribute('data-touch-hover'));
  if(!cancel && d.target)onChoose(d.target);suppress.current=true;
 };
 return {
  onPointerDown:(e:PointerEvent<HTMLElement>)=>{suppress.current=false;if(e.pointerType!=='touch')return;const root=e.currentTarget;drag.current={id:e.pointerId,root,target:mark(root,e.clientX,e.clientY)};root.setPointerCapture(e.pointerId);e.preventDefault()},
  onPointerMove:(e:PointerEvent<HTMLElement>)=>{const d=drag.current;if(d?.id===e.pointerId){d.target=mark(d.root,e.clientX,e.clientY);e.preventDefault()}},
  onPointerUp:(e:PointerEvent<HTMLElement>)=>end(e),onPointerCancel:(e:PointerEvent<HTMLElement>)=>end(e,true),
  onLostPointerCapture:(e:PointerEvent<HTMLElement>)=>end(e,true),
  onClickCapture:(e:import('react').MouseEvent<HTMLElement>)=>{if(suppress.current && e.detail>0){e.preventDefault();e.stopPropagation();suppress.current=false}},
 };
}
