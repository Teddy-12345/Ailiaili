import { useRef, useState } from "react";
import type { Category, Video } from "../domain";
import { duration, views } from "../domain";
export function Icon({ name }: { name: string }) {
  if (name === 'chevron_right' || name === 'chevron_left') return <svg viewBox="0 0 24 24" aria-hidden="true"><path d={name === 'chevron_right' ? 'm9 5 7 7-7 7' : 'm15 5-7 7 7 7'} fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" /></svg>;
  if (name === "__legacy_menu")
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path
          d="M4 6h16M4 12h16M4 18h16"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
        />
      </svg>
    );
  if (name === "__legacy_person")
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <circle cx="12" cy="7" r="4" fill="currentColor" />
        <path d="M4 22v-3a8 8 0 0116 0v3z" fill="currentColor" />
      </svg>
    );
  return (
    <span
      aria-hidden="true"
      className="asset-icon"
      style={{
        maskImage: `url(./icons/${name}.svg)`,
        WebkitMaskImage: `url(./icons/${name}.svg)`,
      }}
    />
  );
}
export function Tool({
  icon,
  label,
  onClick,
  active = false,
  disabled = false,
}: {
  icon: string;
  label: string;
  onClick: () => void;
  active?: boolean;
  disabled?: boolean;
}) {
  return (
    <button
      className={`tool ${active ? "active" : ""}`}
      aria-label={label}
      title={label}
      disabled={disabled}
      onClick={onClick}
    >
      <Icon name={icon} />
    </button>
  );
}
export function Toggle({
  label,
  value,
  onChange,
}: {
  label: string;
  value: boolean;
  onChange: (v: boolean) => void;
}) {
  const pointer = useRef<{ id: number; x: number } | null>(null),
    suppress = useRef(false);
  const [thumb, setThumb] = useState<number | null>(null);
  return (
    <button
      className="switch"
      role="switch"
      aria-checked={value}
      aria-label={label}
      onPointerDown={(e) => {
        if (e.pointerType !== "mouse") {
          pointer.current = { id: e.pointerId, x: e.clientX };
          e.currentTarget.setPointerCapture(e.pointerId);
          e.preventDefault();
        }
      }}
      onPointerMove={(e) => {
        const p = pointer.current;
        if (p?.id === e.pointerId)
          setThumb(
            Math.max(0, Math.min(16, (value ? 16 : 0) + e.clientX - p.x)),
          );
      }}
      onPointerUp={(e) => {
        const p = pointer.current;
        if (p?.id === e.pointerId) {
          const dx = e.clientX - p.x;
          onChange(Math.abs(dx) > 7 ? dx > 0 : !value);
          pointer.current = null;
          setThumb(null);
          suppress.current = true;
        }
      }}
      onPointerCancel={() => {
        pointer.current = null;
        setThumb(null);
        suppress.current = false;
      }}
      onClick={(e) => {
        if (suppress.current && e.detail > 0) {
          suppress.current = false;
          return;
        }
        onChange(!value);
      }}
    >
      <span
        style={
          thumb === null
            ? undefined
            : { transform: `translateX(${thumb}px)`, transition: "none" }
        }
      />
    </button>
  );
}
export function Tabs({
  value,
  onChange,
}: {
  value: Category;
  onChange: (v: Category) => void;
}) {
  return (
    <div className="tabs" role="tablist" aria-label="内容分类">
      {(["视频", "专栏", "笔记"] as Category[]).map((t) => (
        <button
          key={t}
          role="tab"
          aria-selected={value === t}
          onClick={() => onChange(t)}
        >
          {t}
        </button>
      ))}
    </div>
  );
}
export function VideoCard({
  video,
  onOpen,
}: {
  video: Video;
  onOpen: (v: Video) => void;
}) {
  return (
    <button
      className="video-card"
      onClick={() => onOpen(video)}
      aria-label={`播放 ${video.title}`}
    >
      <div className="cover">
        <img src={video.cover || undefined} alt="" loading="lazy" referrerPolicy="no-referrer" />
          {video.duration > 0 && <span className="duration">{duration(video.duration)}</span>}
      </div>
      <div className="card-title">{video.title}</div>
      <div className="card-meta">
        <span>{video.creator}</span>
          {video.views > 0 && <span>{views(video.views)}次播放</span>}
      </div>
    </button>
  );
}
