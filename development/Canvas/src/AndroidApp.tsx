import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from "react";
import { createPortal } from "react-dom";
import { motion, useReducedMotion, useTransform } from "motion/react";
import {thumbnailUrl} from "./mediaWork";
import { ScreenActivity } from "./components/ScreenActivity";
import { WindowedGrid } from "./components/WindowedGrid";
import { Sidebar } from "./components/Sidebar";
import { Icon, Tool } from "./components/ui";
import {
  CanvasTabs,
  MediaTile,
  usePullRefresh,
} from "./components/CanvasMotion";
import { ProfileCard, type Profile } from "./components/ProfileCard";
import { FolderArt } from "./components/FolderArt";
import { canvasBridge as bridge, clearCoverCache } from "./canvasApi";
import type { Category, Section, Video, Theme } from "./domain";

declare global {
  interface Window {
    flutter_inappwebview?: {
      callHandler: (name: string, ...args: unknown[]) => Promise<any>;
    };
    canvasBack?: () => void;
    canvasRefresh?: () => void;
    canvasTheme?: (theme: Theme) => void;
    canvasLoggedOut?: () => void;
    canvasAuthenticated?: () => void;
  }
}
const navItems = [
  { id: "home" as Section, label: "首页", icon: "home" },
  { id: "featured" as Section, label: "精选", icon: "featured" },
  { id: "profile" as Section, label: "个人", icon: "person" },
  { id: "history" as Section, label: "历史", icon: "clock" },
  { id: "favorites" as Section, label: "收藏", icon: "star" },
  { id: "downloads" as Section, label: "下载", icon: "download" },
];
type Entry = Video & {
  url?: string;
  mid?: number;
  aid?: number;
  removeKey?: string;
  feedback?: {id:number;label:string}[];
};
type Folder = {
  id: number;
  title: string;
  count: number;
  cover: string;
  intro?: string;
  privacy?: number;
};
type Person = Profile & { mid: number };
type Snapshot = {
  rows: Entry[];
  folders: Folder[];
  following: Person[];
  people: Person[];
  profile: Profile | null;
  authorProfile: Profile | null;
  more: boolean;
  page: number;
};
const blank = (): Snapshot => ({
  rows: [],
  folders: [],
  following: [],
  people: [],
  profile: null,
  authorProfile: null,
  more: false,
  page: 0,
});
const unique = <T,>(values: T[], id: (v: T) => string | number) => {
  const seen = new Set<string | number>();
  return values.filter((v) => {
    const k = id(v);
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
};
export function AndroidApp() {
  const [phone] = useState(() => new URLSearchParams(location.search).get('device') === 'phone' || (new URLSearchParams(location.search).get('device') !== 'tablet' && Math.min(innerWidth,innerHeight)<600));
  const phoneReturn = useRef<Section>('home');
  const [keyboardOpen,setKeyboardOpen]=useState(false);
  useEffect(()=>{if(!phone)return; const full=window.innerHeight;const update=()=>setKeyboardOpen((window.visualViewport?.height??innerHeight)<full-140);window.visualViewport?.addEventListener('resize',update);return()=>window.visualViewport?.removeEventListener('resize',update)},[phone]);
  const [section, setSection] = useState<Section>("home"),
    [rail, setRail] = useState(false),
    [category, setCategory] = useState<Category>("视频");
  const [text, setText] = useState(""),
    [query, setQuery] = useState(""),
    [searchKind, setSearchKind] = useState<"video" | "user">("video");
  const [suggestions, setSuggestions] = useState<string[]>([]),
    [searchFocused, setSearchFocused] = useState(false);
  const [folder, setFolder] = useState<Folder | null>(null),
    [author, setAuthor] = useState<Person | null>(null),
    [authorFrom, setAuthorFrom] = useState<Section>("profile");
  const [filterOpen, setFilterOpen] = useState(false),
    [filter, setFilter] = useState(""),
    [scopeQuery, setScopeQuery] = useState(""),
    [order, setOrder] = useState("mtime");
  const [data, setData] = useState<Snapshot>(blank),
    [busy, setBusy] = useState(true),
    [error, setError] = useState("");
  const [reading, setReading] = useState<{
    title: string;
    paragraphs: string[];
  } | null>(null);
  const [creating, setCreating] = useState(false),
    [newFolder, setNewFolder] = useState(""),
    [mutationBusy, setMutationBusy] = useState(false);
  const [selecting, setSelecting] = useState(false),
    [selected, setSelected] = useState<Set<string>>(new Set()),
    [confirmRemove, setConfirmRemove] = useState(false);
  const [manageOpen, setManageOpen] = useState(false),
    [historyPaused, setHistoryPaused] = useState(false),
    [confirmClear, setConfirmClear] = useState(false),
    [editTitle, setEditTitle] = useState(""),
    [editPrivacy, setEditPrivacy] = useState(0);
  const viewport = useRef<HTMLElement>(null),
    sentinel = useRef<HTMLDivElement>(null),
    searchRef = useRef<HTMLInputElement>(null);
  const failures = useRef(new Map<string,string>());
  const [session,setSession]=useState(0);
  const cache = useRef(new Map<string, Snapshot>()),
    positions = useRef<Record<string, number>>({}),
    sequence = useRef(0),
    inFlight = useRef("");
  const key = `${section}:${category}:${folder?.id || ""}:${author?.mid || ""}:${section === "search" ? query + ":" + searchKind : ""}:${scopeQuery}:${folder ? order : ""}`;
  const dataKey = useRef(key);
  const activeKey = useRef(key);
  activeKey.current = key;
  const reduce = useReducedMotion(),
    nativePanel = section === "settings" || section === "downloads",
    globalSearch =
      section === "home" || section === "featured" || section === "search";
  const showSearch = globalSearch || !!folder || !!author || filterOpen;
  const workspaceRef = useRef<HTMLDivElement>(null);
  const [columns,setColumns]=useState(2);
  useLayoutEffect(()=>{
    const measure=()=>{
      const grid=viewport.current?.querySelector<HTMLElement>('.canvas-screen[data-active="true"] .video-grid');
      if(grid){const count=getComputedStyle(grid).gridTemplateColumns.split(' ').filter(Boolean).length;if(count)setColumns(count)}
    };
    measure();const observer=new ResizeObserver(measure);if(viewport.current)observer.observe(viewport.current);
    return()=>observer.disconnect();
  },[key,data.rows.length]);  const remember = () => {
    if (viewport.current) positions.current[key] = viewport.current.scrollTop;
  };
  const dismissKeyboard = () => {
    if (document.activeElement instanceof HTMLElement)
      document.activeElement.blur();
    setSearchFocused(false);
    setSuggestions([]);
  };
  const clearSelection = () => {
    setSelecting(false);
    setSelected(new Set());
    setConfirmRemove(false);
    setConfirmClear(false);
  };
  const clearScope = () => {
    setFilter("");
    setScopeQuery("");
    setFilterOpen(false);
    setCreating(false);
    setReading(null);
    setManageOpen(false);
    clearSelection();
  };
  const store = (which: string, next: Snapshot) => {
    cache.current.delete(which);
    cache.current.set(which, next);
    while (cache.current.size > 16) {
      const victim = [...cache.current.keys()].find(
        (k) =>
          !k.startsWith("home:") && !k.startsWith("featured:") && !(k.startsWith('profile:')&&!k.split(':')[3]) && k !== which,
      );
      if (!victim) break;
      cache.current.delete(victim);
    }
  };
  const fetchPage = useCallback(
    async (replace = false) => {
      if (nativePanel || inFlight.current === key) return;
      const previous = cache.current.get(key) || blank(),
        page = replace ? 1 : previous.page + 1;
      if (!replace && previous.page > 0 && !previous.more) return;
      const token = ++sequence.current;
      inFlight.current = key;
      setBusy(true);
      setError("");
      failures.current.delete(key);
      try {
        const r = await bridge("load", {
          section,
          category,
          query,
          searchKind,
          folder: folder?.id,
          author: author?.mid,
          page,
          keyword: scopeQuery,
          order,
        });
        if (token !== sequence.current || activeKey.current !== key) return;
        const rows = unique<Entry>(
          replace ? r.rows || [] : [...previous.rows, ...(r.rows || [])],
          (v) => String(v.id),
        );
        const folders = unique<Folder>(
          replace
            ? r.folders || []
            : [...previous.folders, ...(r.folders || [])],
          (v) => v.id,
        );
        const following = unique<Person>(
          replace
            ? r.following || []
            : [...previous.following, ...(r.following || [])],
          (v) => v.mid,
        );
        const people = unique<Person>(
          replace ? r.people || [] : [...previous.people, ...(r.people || [])],
          (v) => v.mid,
        );
        const progressed =
          replace ||
          rows.length > previous.rows.length ||
          folders.length > previous.folders.length ||
          following.length > previous.following.length ||
          people.length > previous.people.length;
        const next: Snapshot = {
          rows,
          folders,
          following,
          people,
          profile: r.profile || previous.profile,
          authorProfile: r.authorProfile || previous.authorProfile,
          page,
          more: r.more === true && progressed,
        };
        store(key, next);
        setData(next);
      } catch (e) {
        if (token === sequence.current && activeKey.current === key) {
          const message=(e as Error).message || "加载失败，请重试";
          failures.current.set(key,message);
          setError(message);
        }
      } finally {
        if (token === sequence.current) {
          inFlight.current = "";
          setBusy(false);
        }
      }
    },
    [
      key,
      section,
      category,
      query,
      searchKind,
      folder?.id,
      author?.mid,
      scopeQuery,
      order,
      nativePanel,
    ],
  );
  useLayoutEffect(() => {
    sequence.current++;
    inFlight.current = "";
    const restored=cache.current.get(key);
    dataKey.current=key;
    if(restored) store(key,restored);
    setData(restored || blank());
    setBusy(!restored && !failures.current.has(key) && !nativePanel);
    setError(failures.current.get(key)||"");
    clearSelection();
    if (viewport.current)
      viewport.current.scrollTop = positions.current[key] || 0;
    const frame=requestAnimationFrame(()=>{
      if(activeKey.current===key && viewport.current) viewport.current.scrollTop=positions.current[key]||0;
    });
    return()=>cancelAnimationFrame(frame);
  }, [key]);
  useEffect(() => {
    if (nativePanel || cache.current.has(key) || failures.current.has(key)) {
      setBusy(false);
      return;
    }
    void fetchPage(true);
  }, [key, fetchPage, nativePanel]);
  useEffect(() => {
    if (
      nativePanel ||
      mutationBusy ||
      reading ||
      !data.more ||
      busy ||
      error ||
      !viewport.current?.querySelector('.canvas-screen[data-active="true"] .canvas-load-sentinel')
    )
      return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) void fetchPage();
      },
      { root: viewport.current, rootMargin: "0px 0px 420px 0px" },
    );
    const target=viewport.current?.querySelector('.canvas-screen[data-active="true"] .canvas-load-sentinel');
    if(target)observer.observe(target);
    return () => observer.disconnect();
  }, [data.more, data.page, busy, error, nativePanel, reading, mutationBusy, fetchPage]);
  const pull = usePullRefresh(
    viewport,
    !nativePanel && !busy && !reading && !searchFocused && !selecting,
    () => fetchPage(true),
    key,
  );
  const pullOpacity = useTransform(pull.y, [0, 24, 58], [0, 0.6, 1]),
    pullRotate = useTransform(pull.y, [0, 100], [0, 290]);
  const go = (next: Section) => {
    if (next === section && !folder && !author) {
      if (next === "home" || next === "featured") {
        dismissKeyboard();
        viewport.current?.scrollTo({ top: 0, behavior: "smooth" });
        void fetchPage(true);
      }
      return;
    }
    if(phone && ['history','favorites','settings','downloads'].includes(next) && !['history','favorites','settings','downloads'].includes(section))phoneReturn.current=section;
    remember();
    dismissKeyboard();
    clearScope();
    setFolder(null);
    setAuthor(null);
    setCategory("视频");
    setOrder("mtime");
    if (next === "home" || next === "featured") setText("");
    setSection(next);
  };
  const openAuthor = (person: Person) => {
    remember();
    dismissKeyboard();
    clearScope();
    setAuthorFrom(section);
    setFolder(null);
    setAuthor(person);
    setSection("profile");
    setCategory("视频");
  };
  const leaveDetail = () => {
    remember();
    clearScope();
    if (author) {
      setAuthor(null);
      setSection(authorFrom);
    }
    setFolder(null);
  };
  useEffect(() => {
    let theme: Theme = "system";
    const media = matchMedia("(prefers-color-scheme: dark)");
    const apply = () => {
      document.documentElement.dataset.theme =
        theme === "system" ? (media.matches ? "dark" : "light") : theme;
    };
    window.canvasTheme = (value) => {
      theme = value;
      apply();
    };
    bridge("preferences")
      .then((p) => {
        theme = p.theme;
        apply();
      })
      .catch(apply);
    media.addEventListener("change", apply);
    return () => {
      media.removeEventListener("change", apply);
      delete window.canvasTheme;
    };
  }, []);
  useEffect(() => {
    bridge("panel", {
      section,
      rail,
      canBack:
        section !== "home" || rail || !!reading || searchFocused || selecting,
    }).catch(() => {});
    window.canvasRefresh = () => {
      for (const k of cache.current.keys())
        if (
          (k.startsWith("history:") || k.startsWith("favorites:")) &&
          k !== key
        )
          cache.current.delete(k);
      if (section === "history" || section === "favorites")
        void fetchPage(true);
    };
    window.canvasAuthenticated = () => {
      failures.current.clear();
      for(const k of cache.current.keys()) if(!k.startsWith("home:")&&!k.startsWith("featured:"))cache.current.delete(k);
      setSession(v=>v+1);
      void fetchPage(true);
    };
    window.canvasLoggedOut = () => {
      failures.current.clear();
      setSession(v=>v+1);
      cache.current.clear();
      clearCoverCache();
      positions.current = {};
      setData(blank());
      setAuthor(null);
      setFolder(null);
      clearScope();
      setSection("home");
    };
    window.canvasBack = () => {
      if (searchFocused) dismissKeyboard();
      else if (selecting) clearSelection();
      else if (rail) setRail(false);
      else if (reading) setReading(null);
      else if (folder || author) leaveDetail();
      else go(phone ? phoneReturn.current : "home");
    };
    const escape = (e: KeyboardEvent) => {
      if (e.key === "Escape") window.canvasBack?.();
    };
    window.addEventListener("keydown", escape);
    return () => window.removeEventListener("keydown", escape);
  }, [
    section,
    rail,
    folder,
    author,
    authorFrom,
    reading,
    searchFocused,
    selecting,
    fetchPage,
  ]);
  useEffect(() => {
    if (!globalSearch || !searchFocused || !text.trim()) {
      setSuggestions([]);
      return;
    }
    let live = true;
    const timer = setTimeout(
      () =>
        bridge("suggest", { text })
          .then((values) => {
            if (live) setSuggestions(values);
          })
          .catch(() => {}),
      280,
    );
    return () => {
      live = false;
      clearTimeout(timer);
    };
  }, [globalSearch, searchFocused, text]);
  const submit = (value: string) => {
    dismissKeyboard();
    if (!globalSearch) {
      remember();
      setScopeQuery(value.trim());
      return;
    }
    if (!value.trim()) return;
    remember();
    clearScope();
    setQuery(value.trim());
    setText(value.trim());
    if (section === "search" && query === value.trim()) void fetchPage(true);
    else setSection("search");
  };
  const toggle = (id: string) => {
    setSelected((previous) => {
      const next = new Set(previous);
      if (next.has(id)) next.delete(id);
      else if (next.size < 200) next.add(id);
      return next;
    });
    setConfirmRemove(false);
  };
  const open = async (entry: Entry) => {
    if (selecting) {
      toggle(String(entry.id));
      return;
    }
    dismissKeyboard();
    setError("");
    try {
      if (entry.url) {
        const article = await bridge("read", {
          url: entry.url,
          title: entry.title,
          note: category === "笔记",
        });
        remember();
        setReading(article);
      } else
        await bridge("play", {
          bvid: entry.id,
          title: entry.title,
          cover: entry.cover,
        });
    } catch (e) {
      setError((e as Error).message);
    }
  };
  const videoActions=async(video:Entry)=>{
    dismissKeyboard();
    try{
      const result=await bridge('videoActions',{id:video.id});
      if(result?.removed){
        for(const[k,snapshot]of [...cache.current]){if(k.startsWith('home:'))store(k,{...snapshot,rows:snapshot.rows.filter(v=>String(v.id)!==String(video.id)&&(!result.mid||v.mid!==result.mid))})}
        setData(cache.current.get(activeKey.current)||blank());
      }
    }catch(e){setError((e as Error).message)}
  };
  const rootFolders = section === "favorites" && category === "视频" && !folder;
  const queryMatch = (s: string) =>
    !filter || s.toLowerCase().includes(filter.toLowerCase());
  const allVisibleRows = data.rows.filter((v) =>
      queryMatch(`${v.title} ${v.creator}`),
    ),
    visibleFolders = data.folders.filter((f) => queryMatch(f.title));
  const visibleRows=data.more&&!filter&&!selecting&&allVisibleRows.length>=columns
    ?allVisibleRows.slice(0,Math.floor(allVisibleRows.length/columns)*columns):allVisibleRows;
  const selectionItems = rootFolders ? visibleFolders : visibleRows;
  const removeSelected = async () => {
    if (mutationBusy || !selected.size) return;
    setMutationBusy(true);
    sequence.current++;inFlight.current='';setBusy(false);
    setError("");
    try {
      const result = await bridge("remove", {
        section,
        category,
        folder: folder?.id,
        items: selectionItems.filter((v) => selected.has(String(v.id))),
      });
      const removed = new Set<string>(result.removed || []),
        failed = result.failed || [];
      for (const [k, snapshot] of [...cache.current]) {
        const next = {
          ...snapshot,
          rows: snapshot.rows.filter(
            (v) =>
              !removed.has(String(v.id)) ||
              !k.startsWith(`${section}:${category}:${folder?.id || ""}:`),
          ),
          folders: snapshot.folders.filter(
            (v) => !rootFolders || !removed.has(String(v.id)),
          ),
        };
        if (folder)
          next.folders = next.folders.map((f) =>
            f.id === folder.id
              ? { ...f, count: Math.max(0, f.count - removed.size) }
              : f,
          );
        store(k, next);
      }
      clearCoverCache();
      if (activeKey.current === key) {
        setData(cache.current.get(key) || blank());
        setSelected(new Set(failed.map((f: any) => String(f.id))));
        setConfirmRemove(false);
        if (failed.length)
          setError(`${failed.length} 项未能删除：${failed[0].message}`);
        else clearSelection();
      }
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setMutationBusy(false);
    }
  };
  const manage = async (action: string, args: Record<string, unknown> = {}) => {
    setMutationBusy(true);
    sequence.current++;inFlight.current='';setBusy(false);
    setError("");
    try {
      const result = await bridge("manage", { action, ...args });
      if (action === "clearHistory") {
        for (const k of [...cache.current.keys()])
          if (k.startsWith("history:")) cache.current.delete(k);
        if (activeKey.current === key) {
          setConfirmClear(false);
          await fetchPage(true);
        }
      } else if (action === "pauseHistory")
        setHistoryPaused(args.paused === true);
      else if (action === "editFolder") {
        if(folder?.id===args.id)setFolder(previous=>previous?{...previous,title:String(args.title),privacy:Number(args.privacy)}:previous);
        for (const k of [...cache.current.keys()])
          if (k.startsWith("favorites:") && k !== key) cache.current.delete(k);
        if (activeKey.current === key) {
          setManageOpen(false);
          await fetchPage(true);
        }
      }
      return result;
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setMutationBusy(false);
    }
  };
  const openManage = () => {
    setManageOpen((v) => !v);
    setConfirmClear(false);
    if (section === "history" && !manageOpen)
      bridge("manage", { action: "historyStatus" })
        .then((r) => setHistoryPaused(r.paused === true))
        .catch((e) => setError(e.message));
    const target =
      folder || data.folders.find((f) => selected.has(String(f.id)));
    if (target) {
      setEditTitle(target.title);
      setEditPrivacy(target.privacy || 0);
    }
  };
  const openScopeSearch = () => {
    setFilterOpen(true);
    requestAnimationFrame(() => searchRef.current?.focus());
  };
  const contextTitle =
    author?.name ||
    folder?.title ||
    (section === "profile"
      ? "个人"
      : section === "settings"
        ? "设置"
        : section === "downloads"
          ? ""
          : "");
  const label = globalSearch
    ? "搜索视频或用户"
    : section === "history"
      ? "搜索观看历史"
      : section === "favorites"
        ? "搜索收藏"
        : author
          ? "搜索作者视频"
          : "搜索关注";
  const searchBox = (
    <div className="canvas-search search-box">
      <form
        onSubmit={(e) => {
          e.preventDefault();
          submit(globalSearch ? text : filter);
        }}
      >
        <input
          ref={searchRef}
          aria-label={label}
          value={globalSearch ? text : filter}
          enterKeyHint="search"
          type="search"
          autoComplete="off"
          spellCheck={false}
          onChange={(e) =>
            globalSearch ? setText(e.target.value) : setFilter(e.target.value)
          }
          onFocus={() => setSearchFocused(true)}
          onBlur={() => setSearchFocused(false)}
        />
        {(globalSearch ? text : filter) && (
          <button
            type="button"
            aria-label="清空搜索"
            className="clear-search"
            onClick={() => {
              if (globalSearch) setText("");
              else {
                setFilter("");
                setScopeQuery("");
              }
              searchRef.current?.focus();
            }}
          >
            <Icon name="close" />
          </button>
        )}
        <button aria-label="搜索" type="submit">
          <Icon name="search" />
        </button>
      </form>
      {globalSearch && searchFocused && suggestions.length > 0 && (
        <div className="suggestions" role="listbox" aria-label="搜索建议">
          {suggestions.map((s) => (
            <button
              key={s}
              role="option"
              aria-selected={false}
              onPointerDown={(e) => e.preventDefault()}
              onClick={() => submit(s)}
            >
              <Icon name="search" />
              <span>{s}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
  const peopleList = (people: Person[]) =>
    people
      .filter((p) => queryMatch(p.name + " " + (p.sign || "")))
      .map((p) => (
        <button
          key={p.mid}
          className="canvas-follow-row"
          onClick={() => openAuthor(p)}
        >
          <img
            className="canvas-avatar"
            src={p.face ? thumbnailUrl(p.face,true) : undefined}
            alt=""
            loading="lazy"
            referrerPolicy="no-referrer"
          />
          <span className="canvas-follow-info">
            <strong>{p.name}</strong>
            {p.sign && <span>{p.sign}</span>}
          </span>
          <Icon name="chevron_right" />
        </button>
      ));
  const empty =
    !data.rows.length &&
    !data.folders.length &&
    !data.following.length &&
    !data.people.length;
  const visibleEmpty =
    section === "search" && searchKind === "user"
      ? !data.people.length
      : rootFolders
        ? !visibleFolders.length
        : section === "profile" && !author
          ? !data.following.filter((p) =>
              queryMatch(p.name + " " + (p.sign || "")),
            ).length
          : !visibleRows.length;
  const editFolder =
    folder ||
    (selected.size === 1
      ? data.folders.find((f) => selected.has(String(f.id)))
      : undefined);
  return (
    <div
      className={`app native-canvas canvas-v6 canvas-v7 canvas-v9 ${phone ? "phone-layout" : ""} ${phone && (keyboardOpen || searchFocused) ? "phone-keyboard" : ""} ${phone && ["history","favorites","settings","downloads"].includes(section) ? "phone-secondary" : ""} ${rail ? "rail-open" : ""}`}
    >
      {!busy && !error && visibleEmpty && !nativePanel && !reading && createPortal(
        <div className="empty-state canvas-no-data"><Icon name="no-data"/><p>无数据</p></div>, document.body)}
      {!phone && <Sidebar
        open={rail}
        section={section === "search" ? "home" : section}
        items={navItems}
        onToggle={() => {
          dismissKeyboard();
          setRail((v) => !v);
        }}
        onClose={() => setRail(false)}
        onNavigate={go}
      />}
      {phone && <nav className="phone-bottom-nav" aria-label="手机主导航">{['featured','home','profile'].map(id => {const item=navItems.find(v=>v.id===id)!;return <button key={id} aria-label={item.label} aria-current={(section===id||(section==='search'&&id==='home'))?'page':undefined} onClick={()=>go(item.id)}><Icon name={item.icon}/></button>})}</nav>}

      <div className="workspace" ref={workspaceRef}>
        {phone ? <header className={`phone-header ${showSearch && !globalSearch ? 'with-scope-search' : ''}`}>
          <div className={`phone-header-row ${globalSearch ? 'with-global-search' : ''}`}>
            <div className="phone-header-leading">{(folder||author) ? <Tool icon="chevron_left" label="返回上一级" onClick={leaveDetail}/> : ['history','favorites','settings','downloads','search'].includes(section) ? <Tool icon="chevron_left" label="返回上一页" onClick={()=>go(phoneReturn.current)}/> : null}
              {!globalSearch && (folder||author) && <h1>{contextTitle}</h1>}
              {!globalSearch && !folder && !author && !['history','favorites'].includes(section) && <h1>{contextTitle}</h1>}
            </div>
            {globalSearch ? searchBox : (section==='history'||section==='favorites') && !folder ? <CanvasTabs value={category} onChange={v=>{remember();dismissKeyboard();clearScope();setCategory(v)}}/> : null}
            <div className="phone-header-trailing">
              {section==='profile'&&!author && <><Tool icon="search" label="搜索关注" onClick={openScopeSearch}/><Tool icon="download" label="下载" onClick={()=>go('downloads')}/><Tool icon="settings" label="设置" onClick={()=>go('settings')}/></>}
              {(section==='home'||section==='featured') && <><Tool icon="clock" label="历史" onClick={()=>go('history')}/><Tool icon="star" label="收藏" onClick={()=>go('favorites')}/></>}
              {(section==='history'||section==='favorites') && <>
                {section==='favorites'&&!folder&&category==='视频' && <Tool icon="plus" label="新建收藏夹" onClick={()=>setCreating(v=>!v)}/>}
                <Tool icon="check" label={selecting?'退出多选':'多选'} active={selecting} onClick={()=>{if(selecting)clearSelection();else setSelecting(true)}}/>
                <Tool icon="more" label="管理" active={manageOpen} onClick={openManage}/>
                {!folder && <Tool icon="search" label="搜索当前内容" onClick={openScopeSearch}/>}
              </>}
            </div>
          </div>
          {showSearch&&!globalSearch && <div className="phone-scope-search">{searchBox}</div>}
        </header> : <>
        <header
          className={`canvas-header ${showSearch ? "has-search" : ""} ${globalSearch ? "global-search-header" : ""}`}
        >
          <div className="canvas-heading">
            {phone && ['history','favorites','settings','downloads','search'].includes(section) && <Tool icon="chevron_left" label="返回上一页" onClick={()=>go(phoneReturn.current)}/>}
            {(section === "history" || section === "favorites") && !folder ? (
              <CanvasTabs
                value={category}
                onChange={(value) => {
                  remember();
                  dismissKeyboard();
                  clearScope();
                  setCategory(value);
                }}
              />
            ) : (
              contextTitle && (
                <div className="canvas-context">
                  {(folder || author) && (
                    <Tool
                      icon="chevron_left"
                      label={
                        folder
                          ? "返回收藏夹"
                          : authorFrom === "search"
                            ? "返回搜索结果"
                            : authorFrom === "home"
                              ? "返回首页"
                              : authorFrom === "featured"
                                ? "返回精选"
                                : "返回关注列表"
                      }
                      onClick={leaveDetail}
                    />
                  )}
                  <h1 title={contextTitle}>{contextTitle}</h1>
                </div>
              )
            )}
          </div>
          {showSearch && searchBox}
          <div className="canvas-header-actions">
            {phone && section==='profile' && !author && <div className="phone-utilities"><Tool icon="search" label="搜索关注" onClick={openScopeSearch}/><Tool icon="download" label="下载" onClick={()=>go('downloads')}/><Tool icon="settings" label="设置" onClick={()=>go('settings')}/></div>}
            {phone && (section==='home'||section==='featured') && <div className="phone-utilities"><Tool icon="clock" label="历史" onClick={()=>go('history')}/><Tool icon="star" label="收藏" onClick={()=>go('favorites')}/></div>}
            {section === "favorites" && category === "视频" && !folder && (
              <Tool
                icon="plus"
                label="新建收藏夹"
                onClick={() => {
                  dismissKeyboard();
                  setCreating((v) => !v);
                }}
              />
            )}
            {(section === "history" || section === "favorites") && (
              <>
                <Tool
                  icon="check"
                  label={selecting ? "退出多选" : "多选"}
                  active={selecting}
                  onClick={() => {
                    if (selecting) clearSelection();
                    else {
                      setSelecting(true);
                      setManageOpen(false);
                    }
                  }}
                />
                <Tool
                  icon="more"
                  label="管理"
                  active={manageOpen}
                  onClick={openManage}
                />
              </>
            )}
            {!globalSearch && !nativePanel && !folder && !author && !(phone && section==='profile') && (
              <Tool
                icon={filterOpen ? "close" : "search"}
                label={filterOpen ? "收起搜索" : "搜索当前内容"}
                onClick={() => {
                  if (filterOpen) {
                    dismissKeyboard();
                    setFilterOpen(false);
                    setFilter("");
                    setScopeQuery("");
                  } else openScopeSearch();
                }}
              />
            )}
          </div>
        </header>
        </>}
        {section === "search" && (
          <div
            className="search-result-tabs"
            role="tablist"
            aria-label="搜索结果类型"
          >
            {(["video", "user"] as const).map((kind) => (
              <button
                key={kind}
                role="tab"
                aria-selected={searchKind === kind}
                onClick={() => {
                  remember();
                  clearSelection();
                  setSearchKind(kind);
                }}
              >
                {kind === "video" ? "视频" : "用户"}
              </button>
            ))}
          </div>
        )}
        <div className="canvas-stage">
          {!nativePanel && (
            <motion.div
              className={`pull-indicator ${pull.refreshing ? "is-refreshing" : ""}`}
              aria-hidden={!pull.refreshing}
              style={{
                opacity: pull.refreshing ? 1 : pullOpacity,
                rotate: pull.refreshing ? 0 : pullRotate,
              }}
            >
              <span className="canvas-spinner" />
            </motion.div>
          )}
          <main
            ref={viewport}
            className="main canvas-scroll"
            onPointerDown={(e) => {
              if (!(e.target as Element).closest("input")) dismissKeyboard();
            }}
          >
            <motion.div className="canvas-content" style={{ y: pull.y }}>
              <RetainedScreens key={session} active={key} ready={dataKey.current===key}>
                {selecting && (
                  <div
                    className="selection-toolbar"
                    role="region"
                    aria-label="多选管理"
                  >
                    <span>已选 {selected.size} 项</span>
                    <button
                      onClick={() =>
                        setSelected(
                          new Set(
                            selectionItems
                              .slice(0, 200)
                              .map((v) => String(v.id)),
                          ),
                        )
                      }
                    >
                      全选已加载
                    </button>
                    <button onClick={() => setSelected(new Set())}>
                      清除选择
                    </button>
                    {!confirmRemove ? (
                      <button
                        className="danger-text"
                        disabled={!selected.size || mutationBusy}
                        onClick={() => setConfirmRemove(true)}
                      >
                        删除所选
                      </button>
                    ) : (
                      <>
                        <span>
                          {rootFolders
                            ? "将删除所选收藏夹及其收藏记录，原视频不会被删除。"
                            : "确认删除所选记录？"}
                        </span>
                        <button
                          className="danger-text"
                          disabled={mutationBusy}
                          onClick={removeSelected}
                        >
                          {mutationBusy ? "正在删除…" : "确认删除"}
                        </button>
                        <button
                          disabled={mutationBusy}
                          onClick={() => setConfirmRemove(false)}
                        >
                          取消删除
                        </button>
                      </>
                    )}
                    <button onClick={clearSelection}>完成</button>
                  </div>
                )}
                {manageOpen && (
                  <section className="canvas-management" aria-label="管理选项">
                    {section === "history" && (
                      <>
                        <label>
                          <input
                            type="checkbox"
                            checked={historyPaused}
                            disabled={mutationBusy}
                            onChange={(e) =>
                              manage("pauseHistory", {
                                paused: e.target.checked,
                              })
                            }
                          />
                          暂停记录浏览历史
                        </label>
                        {!confirmClear ? (
                          <button
                            className="danger-text"
                            onClick={() => setConfirmClear(true)}
                          >
                            清空浏览记录
                          </button>
                        ) : (
                          <div className="inline-confirm">
                            <span>
                              将清空全部视频、专栏与本地笔记浏览记录。
                            </span>
                            <button
                              className="danger-text"
                              disabled={mutationBusy}
                              onClick={() => manage("clearHistory")}
                            >
                              确认清空
                            </button>
                            <button onClick={() => setConfirmClear(false)}>
                              取消
                            </button>
                          </div>
                        )}
                      </>
                    )}
                    {section === "favorites" && folder && (
                      <label>
                        排序
                        <select
                          aria-label="收藏排序"
                          value={order}
                          onChange={(e) => {
                            remember();
                            setOrder(e.target.value);
                          }}
                        >
                          <option value="mtime">收藏时间</option>
                          <option value="view">播放量</option>
                          <option value="pubtime">投稿时间</option>
                        </select>
                      </label>
                    )}
                    {section === "favorites" &&
                    category === "视频" &&
                    editFolder ? (
                      <form
                        className="canvas-inline-form"
                        onSubmit={(e) => {
                          e.preventDefault();
                          manage("editFolder", {
                            id: editFolder.id,
                            title: editTitle,
                            privacy: editPrivacy,
                          });
                        }}
                      >
                        <label>
                          收藏夹名称
                          <input
                            aria-label="编辑收藏夹名称"
                            value={editTitle}
                            onChange={(e) => setEditTitle(e.target.value)}
                            maxLength={80}
                          />
                        </label>
                        <label>
                          <input
                            type="checkbox"
                            checked={editPrivacy === 1}
                            onChange={(e) =>
                              setEditPrivacy(e.target.checked ? 1 : 0)
                            }
                          />
                          仅自己可见
                        </label>
                        <button disabled={mutationBusy || !editTitle.trim()}>
                          保存
                        </button>
                      </form>
                    ) : (
                      section === "favorites" &&
                      category === "视频" &&
                      !folder && (
                        <p>
                          勾选一个收藏夹后可修改名称与可见性；多选可删除收藏夹。
                        </p>
                      )
                    )}
                  </section>
                )}
                {creating && section === "favorites" && (
                  <form
                    className="canvas-inline-form"
                    onSubmit={async (e) => {
                      e.preventDefault();
                      if (mutationBusy || !newFolder.trim()) return;
                      setMutationBusy(true);
                      try {
                        await bridge("createFolder", {
                          title: newFolder.trim(),
                        });
                        setNewFolder("");
                        setCreating(false);
                        await fetchPage(true);
                      } catch (e) {
                        setError((e as Error).message);
                      } finally {
                        setMutationBusy(false);
                      }
                    }}
                  >
                    <input
                      aria-label="收藏夹名称"
                      value={newFolder}
                      onChange={(e) => setNewFolder(e.target.value)}
                      autoFocus
                      maxLength={80}
                      enterKeyHint="done"
                    />
                    <button disabled={!newFolder.trim() || mutationBusy}>
                      创建
                    </button>
                    <button type="button" onClick={() => setCreating(false)}>
                      取消
                    </button>
                  </form>
                )}
                {error && (
                  <div className="inline-error" role="alert">
                    <Icon name="warning" />
                    <p>{error}</p>
                    {error.includes("登录") && (
                      <button
                        className="primary-button"
                        onClick={() =>
                          bridge("login")
                            .then(() => fetchPage(true))
                            .catch((e) => setError(e.message))
                        }
                      >
                        登录
                      </button>
                    )}
                    <button
                      className="text-button"
                      onClick={() => fetchPage(true)}
                    >
                      重试
                    </button>
                  </div>
                )}
                {reading ? (
                  <article className="reader">
                    <button
                      className="text-button"
                      onClick={() => setReading(null)}
                    >
                      收起正文
                    </button>
                    <h1>{reading.title}</h1>
                    {reading.paragraphs.map((p, i) => (
                      <p key={i}>{p}</p>
                    ))}
                  </article>
                ) : (
                  <>
                    {section === "profile" && author && (
                      <ProfileCard
                        key={author.mid}
                        profile={{
                          ...author,
                          ...data.authorProfile,
                          name: data.authorProfile?.name || author.name,
                          face: data.authorProfile?.face || author.face,
                          sign: data.authorProfile?.sign || author.sign,
                        }}
                      />
                    )}
                    {section === "profile" && !author && data.profile && (
                      <div className="canvas-profile">
                        <ProfileCard profile={data.profile} own />
                        <div className="canvas-follow-list">
                          {peopleList(data.following)}
                        </div>
                      </div>
                    )}
                    {section === "search" && searchKind === "user" && (
                      <div className="canvas-people-list">
                        {peopleList(data.people)}
                      </div>
                    )}
                    {rootFolders && (
                      <WindowedGrid className="canvas-folder-grid" items={visibleFolders} renderItem={(f) => (
                          <div
                            key={f.id}
                            className={`selection-cell ${selected.has(String(f.id)) ? "is-selected" : ""}`}
                          >
                            <button
                              className="canvas-folder-card"
                              onClick={() => {
                                if (selecting) toggle(String(f.id));
                                else {
                                  remember();
                                  clearScope();
                                  setFolder(f);
                                  setOrder("mtime");
                                }
                              }}
                            >
                              <FolderArt folder={f} />
                              <strong>{f.title}</strong>
                            </button>
                            {selecting && (
                              <input
                                type="checkbox"
                                className="selection-checkbox"
                                aria-label={`选择 ${f.title}`}
                                checked={selected.has(String(f.id))}
                                onChange={() => toggle(String(f.id))}
                              />
                            )}
                          </div>
                        )}/>
                    )}
                    {visibleRows.length > 0 && (
                      <>
                        <WindowedGrid className="video-grid" items={visibleRows} renderItem={(v,i) => (
                            <div
                              key={v.id}
                              className={`selection-cell ${selected.has(String(v.id)) ? "is-selected" : ""}`}
                            >
                              <MediaTile
                                video={v}
                                index={i}
                                onStory={phone&&!selecting&&/^BV[0-9A-Za-z]+$/.test(v.id)?()=>{dismissKeyboard();void bridge('story',{bvid:v.id}).catch(e=>setError(e.message))}:undefined}
                                onHold={v.feedback?.length && !selecting ? () => videoActions(v) : undefined}
                                onOpen={() => open(v)}
                                onAuthor={
                                  v.mid &&
                                  !selecting &&
                                  Number(v.mid) !== author?.mid
                                    ? () =>
                                        openAuthor({
                                          mid: Number(v.mid),
                                          name: v.creator,
                                          face: "",
                                          sign: "",
                                        })
                                    : undefined
                                }
                              />
                              {selecting && (
                                <input
                                  type="checkbox"
                                  className="selection-checkbox"
                                  aria-label={`选择 ${v.title}`}
                                  checked={selected.has(String(v.id))}
                                  onChange={() => toggle(String(v.id))}
                                />
                              )}
                            </div>
                          )}/>
                        
                      </>
                    )}
                    {busy && empty && !nativePanel && <div className="canvas-first-loading" role="status" aria-label="正在加载"><span className="canvas-spinner" /></div>}
                    <div
                      ref={sentinel}
                      className="canvas-load-sentinel"
                      aria-hidden="true"
                    />
                    {busy && !empty && !pull.refreshing && (
                      <div
                        className="canvas-loading"
                        role="status"
                        aria-label="正在加载更多"
                      >
                        <span className="canvas-spinner" />
                      </div>
                    )}
                  </>
                )}
              </RetainedScreens>
            </motion.div>
          </main>
        </div>
      </div>
    </div>
  );
}

function RetainedScreens({active,children,ready}:{active:string;children:React.ReactNode;ready:boolean}) {
  const screens=useRef(new Map<string,React.ReactNode>());
  if(ready)screens.current.set(active,children);
  if(screens.current.size>4){const victim=[...screens.current.keys()].find(k=>k!==active&&!k.startsWith('home:'));if(victim)screens.current.delete(victim)}
  return [...screens.current].map(([key,node])=><div key={key} className="canvas-screen" data-active={key===active} style={{display:key===active?'block':'none'}} inert={key!==active} aria-hidden={key!==active}><ScreenActivity.Provider value={key===active}>{node}</ScreenActivity.Provider></div>);
}
