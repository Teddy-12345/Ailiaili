import { useRef, useState, useLayoutEffect } from "react";
import { motion, useReducedMotion } from "motion/react";
import type { Section } from "../domain";
import { Icon, Tool } from "./ui";
import { useTouchChoice } from "../webtv/useTouchChoice";
type Item = { id: Section; label: string; icon: string };
type Props = {
  open: boolean;
  section: Section;
  items: Item[];
  onToggle: () => void;
  onClose: () => void;
  onNavigate: (section: Section) => void;
};
export function Sidebar({
  open,
  section,
  items,
  onToggle,
  onClose,
  onNavigate,
}: Props) {
  const [preview, setPreview] = useState<string | null>(null),
    start = useRef<{ x: number; y: number } | null>(null);
  const reduce = useReducedMotion();
  const railRef=useRef<HTMLElement>(null);
  const [highlight,setHighlight]=useState({y:77,height:42});
  useLayoutEffect(()=>{
    const update=()=>{
      const button=railRef.current?.querySelector<HTMLElement>(`[data-side-section="${preview||section}"]`);
      if(button&&railRef.current)setHighlight({y:button.getBoundingClientRect().top-railRef.current.getBoundingClientRect().top+3,height:button.offsetHeight-6});
    };
    update();const observer=new ResizeObserver(update);
    if(railRef.current){observer.observe(railRef.current);railRef.current.querySelectorAll('nav,button,.rail-bottom').forEach(el=>observer.observe(el))}
    window.addEventListener('resize',update);window.visualViewport?.addEventListener('resize',update);
    return()=>{observer.disconnect();window.removeEventListener('resize',update);window.visualViewport?.removeEventListener('resize',update)};
  },[preview,section,open]);
  const touch = useTouchChoice("[data-side-section]", (el) =>
    onNavigate(el.dataset.sideSection as Section),
  );
  const updatePreview = (root: HTMLElement) =>
    setPreview(
      root.querySelector<HTMLElement>("[data-touch-hover]")?.dataset
        .sideSection || null,
    );
  const button = (item: Item) => (
    <button
      key={item.id}
      type="button"
      className={`tool ${section === item.id ? "active" : ""}`}
      data-side-section={item.id}
      aria-label={item.label}
      title={item.label}
      aria-current={section === item.id ? "page" : undefined}
      onClick={() => onNavigate(item.id)}
    >
      <Icon name={item.icon} />
    </button>
  );
  return (
    <>
      <div className="menu-trigger">
        <Tool
          icon="menu"
          label={open ? "收起侧栏" : "展开侧栏"}
          onClick={onToggle}
        />
      </div>
      <aside
        ref={railRef}
        className="rail"
        aria-label="侧边抽屉"
        aria-hidden={!open}
        inert={!open}
        onPointerDown={(e) => {
          start.current = { x: e.clientX, y: e.clientY };
          touch.onPointerDown(e);
          updatePreview(e.currentTarget);
        }}
        onPointerMove={(e) => {
          touch.onPointerMove(e);
          updatePreview(e.currentTarget);
        }}
        onPointerUp={(e) => {
          const s = start.current;
          if (
            s &&
            e.clientX - s.x < -28 &&
            Math.abs(e.clientX - s.x) > Math.abs(e.clientY - s.y)
          ) {
            touch.onPointerCancel(e);
            onClose();
          } else touch.onPointerUp(e);
          setPreview(null);
          start.current = null;
        }}
        onPointerCancel={(e) => {
          touch.onPointerCancel(e);
          setPreview(null);
          start.current = null;
        }}
        onLostPointerCapture={(e) => {
          touch.onLostPointerCapture(e);
          setPreview(null);
        }}
        onClickCapture={touch.onClickCapture}
      >
        <motion.span aria-hidden="true" className="rail-selection rail-highlight" initial={false}
          animate={{y:highlight.y,height:highlight.height}} transition={reduce?{duration:0}:{type:'spring',stiffness:300,damping:30}}/>
        <nav aria-label="主导航">{items.map(button)}</nav>
        <div className="rail-bottom">
          {button({ id: "settings", label: "设置", icon: "settings" })}
        </div>
      </aside>
    </>
  );
}
