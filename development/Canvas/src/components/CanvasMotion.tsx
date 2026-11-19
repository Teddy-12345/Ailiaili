import { CachedPoster } from './CachedPoster';
import { useEffect, useRef, useState, type RefObject } from "react";
import {
  animate,
  motion,
  useMotionValue,
  useReducedMotion,
} from "motion/react";
import RubberSegment from "../webtv/RubberSegment";
import { Icon } from "./ui";
import { duration, views, type Category, type Video } from "../domain";

// WebTV MediaCard.tsx: arrival timing and layout spring. Poster reveal uses
// WebTV MediaCard.css / Poster.tsx, without its server URL/inspection adapters.
export const arrival = {
  opacity: { duration: 0.24 },
  y: {
    duration: 0.32,
    ease: [0.2, 0.8, 0.2, 1] as [number, number, number, number],
  },
};
export const canvasSpring = {
  type: "spring" as const,
  stiffness: 300,
  damping: 30,
};

export function CanvasTabs({
  value,
  onChange,
}: {
  value: Category;
  onChange: (value: Category) => void;
}) {
  return (
    <RubberSegment
      items={["视频", "专栏", "笔记"]}
      value={value}
      onChange={(value) => onChange(value as Category)}
      size="lg"
      radius={9}
      trackColor="transparent"
      thumbColor="var(--soft)"
      textColor="var(--muted)"
      activeTextColor="var(--accent)"
      aria-label="内容分类"
      className="canvas-tabs"
    />
  );
}

export function MediaTile({video,index,onOpen,onAuthor,onHold,onStory}: {
 video:Video;index:number;onOpen:()=>void;onAuthor?:()=>void;onHold?:()=>void;onStory?:()=>void;
}) {
 const press=useRef<{x:number;y:number;timer:ReturnType<typeof setTimeout>}|null>(null),fired=useRef(false);
 const cancel=()=>{if(press.current)clearTimeout(press.current.timer);press.current=null};
 useEffect(()=>cancel,[]);
 return <article className="video-card canvas-card" aria-label={video.title}
  onPointerDown={e=>{if(!onHold||e.button!==0||(e.target as Element).closest('.card-creator,.story-card-entry'))return;cancel();fired.current=false;press.current={x:e.clientX,y:e.clientY,timer:setTimeout(()=>{fired.current=true;onHold()},450)}}}
  onPointerMove={e=>{const p=press.current;if(p&&Math.hypot(e.clientX-p.x,e.clientY-p.y)>9)cancel()}}
  onPointerUp={cancel} onPointerCancel={cancel}
  onClickCapture={e=>{if(fired.current){e.preventDefault();e.stopPropagation();fired.current=false}}}
  onContextMenu={e=>{if((e.target as Element).closest('.card-creator,.story-card-entry'))return;e.preventDefault();cancel();if(onHold&&!fired.current){fired.current=true;onHold()}}}>
  <CachedPoster key={video.cover} src={video.cover} eager={index<2}>
   <button type="button" className="cover-action" aria-label={`播放 ${video.title}`} onClick={onOpen}/>
   {video.duration>0&&<span className="duration">{duration(video.duration)}</span>}
  </CachedPoster>
  <div className="canvas-card-info">
   <button className="card-title" type="button" onClick={onOpen}>{video.title}</button>
   <div className="card-meta">
    {onAuthor?<button className="card-creator" type="button" title={video.creator} aria-label={`打开${video.creator}的空间`} onClick={onAuthor}>{video.creator}</button>:<span className="card-creator">{video.creator}</span>}
    {video.views>0&&<span>{views(video.views)}次播放</span>}{onStory&&<button className="story-card-entry" aria-label={`竖屏刷视频：${video.title}`} onClick={onStory}><Icon name="featured"/></button>}
   </div>
  </div>
 </article>;
}
export function CardSkeletons() {
  return (
    <div
      className="video-grid canvas-placeholders"
      aria-label="正在加载内容"
      role="status"
    >
      {Array.from({ length: 8 }, (_, i) => (
        <div className="canvas-card" key={i}>
          <div className="cover canvas-skeleton" />
          <div className="canvas-card-info">
            <div className="skeleton-line canvas-skeleton" />
            <div className="skeleton-line short canvas-skeleton" />
          </div>
        </div>
      ))}
    </div>
  );
}

/** Touch listener stays non-passive only on the scroll surface. The motion value
 * follows the finger without rerendering the video grid every frame. Resistance
 * is WebTV RubberSegment's rubber() formula, spring is its MediaCard spring. */
export function usePullRefresh(
  viewport: RefObject<HTMLElement | null>,
  enabled: boolean,
  refresh: () => Promise<unknown>,
  resetKey: string,
) {
  const y = useMotionValue(0),
    [refreshing, setRefreshing] = useState(false);
  const refreshRef = useRef(refresh),
    enabledRef = useRef(enabled),
    refreshingRef = useRef(false);
  const animation = useRef<ReturnType<typeof animate> | null>(null);
  refreshRef.current = refresh;
  enabledRef.current = enabled;
  useEffect(() => {
    animation.current?.stop();
    y.set(0);
  }, [resetKey, y]);
  useEffect(() => {
    const el = viewport.current;
    if (!el) return;
    let start: { x: number; y: number; active: boolean } | null = null;
    let suppressUntil = 0;
    const relax = () => {
      animation.current?.stop();
      animation.current = animate(
        y,
        0,
        matchMedia("(prefers-reduced-motion: reduce)").matches
          ? { duration: 0 }
          : canvasSpring,
      );
    };
    const cancel = () => {
      start = null;
      relax();
    };
    const down = (e: TouchEvent) => {
      if (
        e.touches.length !== 1 ||
        !enabledRef.current ||
        refreshingRef.current ||
        el.scrollTop > 1 ||
        (e.target as Element).closest(
          "input,textarea,select,.tool,.rubber-segment",
        )
      ) {
        start = null;
        return;
      }
      animation.current?.stop();
      start = {
        x: e.touches[0].clientX,
        y: e.touches[0].clientY,
        active: false,
      };
    };
    const move = (e: TouchEvent) => {
      if (!start || e.touches.length !== 1) return;
      const dx = e.touches[0].clientX - start.x,
        dy = e.touches[0].clientY - start.y;
      if (
        !start.active &&
        (dy < -8 || (Math.abs(dx) > 12 && Math.abs(dx) > Math.abs(dy)))
      ) {
        start = null;
        return;
      }
      if (dy > 8 && dy > Math.abs(dx) * 1.2) start.active = true;
      if (!start.active) return;
      e.preventDefault();
      const distance = Math.max(0, dy - 8);
      y.set((distance * 160 * 0.55) / (160 + 0.55 * distance));
    };
    const up = (e: TouchEvent) => {
      if (!start) return;
      const dragged = start.active,
        trigger = dragged && y.get() >= 58;
      start = null;
      if (dragged) {
        e.preventDefault();
        suppressUntil = performance.now() + 400;
      }
      relax();
      if (trigger && !refreshingRef.current && enabledRef.current) {
        refreshingRef.current = true;
        setRefreshing(true);
        Promise.resolve(refreshRef.current()).finally(() => {
          refreshingRef.current = false;
          setRefreshing(false);
        });
      }
    };
    const click = (e: MouseEvent) => {
      if (performance.now() < suppressUntil) {
        e.preventDefault();
        e.stopImmediatePropagation();
      }
    };
    el.addEventListener("touchstart", down, { passive: true });
    el.addEventListener("touchmove", move, { passive: false });
    el.addEventListener("touchend", up, { passive: false });
    el.addEventListener("touchcancel", cancel, { passive: true });
    el.addEventListener("click", click, true);
    return () => {
      el.removeEventListener("touchstart", down);
      el.removeEventListener("touchmove", move);
      el.removeEventListener("touchend", up);
      el.removeEventListener("touchcancel", cancel);
      el.removeEventListener("click", click, true);
      animation.current?.stop();
    };
  }, [viewport, y]);
  return { y, refreshing };
}
