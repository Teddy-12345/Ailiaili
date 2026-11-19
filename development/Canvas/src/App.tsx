import { Sidebar } from "./components/Sidebar";
import { Icon, Tool, Toggle, Tabs, VideoCard } from "./components/ui";
import { SettingsView } from "./views/SettingsView";
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import type { Category, Preferences, Section, Theme, Video } from "./domain";
import {
  defaults,
  duration,
  repository,
  sampleArticles,
  sampleNotes,
  views,
} from "./domain";

const navItems: { id: Section; label: string; icon: string }[] = [
  { id: "home", label: "首页", icon: "home" },
  { id: "profile", label: "个人", icon: "person" },
  { id: "history", label: "历史", icon: "clock" },
  { id: "favorites", label: "收藏", icon: "folder" },
  { id: "downloads", label: "缓存", icon: "download" },
];
function loadPrefs(): Preferences {
  try {
    return {
      ...defaults,
      ...JSON.parse(localStorage.getItem("bili-preview-prefs") || "{}"),
    };
  } catch {
    return defaults;
  }
}
export function App() {
  const [section, setSection] = useState<Section>("home"),
    [rail, setRail] = useState(false),
    [prefs, setPrefs] = useState(loadPrefs);
  const [query, setQuery] = useState(""),
    [searchText, setSearchText] = useState(""),
    [suggest, setSuggest] = useState(false);
  const [historyTab, setHistoryTab] = useState<Category>("视频"),
    [favoriteTab, setFavoriteTab] = useState<Category>("视频");
  const [settingsTab, setSettingsTab] = useState("通用"),
    [folder, setFolder] = useState<string | null>(null),
    [author, setAuthor] = useState<string | null>(null);
  const [followed, setFollowed] = useState(() => repository.following()),
    [watched, setWatched] = useState<Video[]>(() =>
      repository.recommendations().slice(1, 5),
    );
  const [current, setCurrent] = useState<Video | null>(null),
    [previous, setPrevious] = useState<Section>("home"),
    [saved, setSaved] = useState<string[]>(() =>
      repository
        .recommendations()
        .slice(0, 6)
        .map((v) => v.id),
    );
  const [article, setArticle] = useState<{
      title: string;
      body: string;
    } | null>(null),
    [message, setMessage] = useState("");
  const [editFolders, setEditFolders] = useState(false),
    [folders, setFolders] = useState(["默认收藏夹", "值得再看", "影像与生活"]);
  const [tasks, setTasks] = useState([
    { video: repository.recommendations()[0], progress: 68, paused: false },
    { video: repository.recommendations()[1], progress: 100, paused: false },
  ]);
  const [newFolder, setNewFolder] = useState(""),
    [librarySearch, setLibrarySearch] = useState(""),
    [showLibrarySearch, setShowLibrarySearch] = useState(false);
  const [recentSearch, setRecentSearch] = useState<string[]>([]),
    [reverse, setReverse] = useState(false);
  const viewport = useRef<HTMLElement>(null),
    positions = useRef<Record<string, number>>({}),
    searchBox = useRef<HTMLDivElement>(null),
    toastTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const screenKey = `${section}:${section === "favorites" ? favoriteTab + folder : section === "history" ? historyTab : section === "settings" ? settingsTab : section === "profile" ? author : ""}`;
  useEffect(() => {
    localStorage.setItem("bili-preview-prefs", JSON.stringify(prefs));
    const media = matchMedia("(prefers-color-scheme: dark)");
    const apply = () => {
      document.documentElement.dataset.theme =
        prefs.theme === "system"
          ? media.matches
            ? "dark"
            : "light"
          : prefs.theme;
    };
    apply();
    media.addEventListener("change", apply);
    return () => media.removeEventListener("change", apply);
  }, [prefs]);
  useEffect(
    () => () => {
      if (toastTimer.current) clearTimeout(toastTimer.current);
    },
    [],
  );
  useEffect(() => {
    const escape = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setRail(false);
        setSuggest(false);
      }
    };
    window.addEventListener("keydown", escape);
    return () => window.removeEventListener("keydown", escape);
  }, []);
  useEffect(() => {
    const close = (e: PointerEvent) => {
      if (!searchBox.current?.contains(e.target as Node)) setSuggest(false);
    };
    document.addEventListener("pointerdown", close);
    return () => document.removeEventListener("pointerdown", close);
  }, []);
  useLayoutEffect(() => {
    if (viewport.current)
      viewport.current.scrollTop = positions.current[screenKey] || 0;
  }, [screenKey]);
  const remember = () => {
    if (viewport.current)
      positions.current[screenKey] = viewport.current.scrollTop;
  };
  const go = (next: Section) => {
    remember();
    setArticle(null);
    setSection(next);
    setShowLibrarySearch(false);
    setLibrarySearch("");
    setSuggest(false);
  };
  const notify = (text: string) => {
    setMessage(text);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setMessage(""), 2200);
  };
  const change = <K extends keyof Preferences>(key: K, value: Preferences[K]) =>
    setPrefs((p) => ({ ...p, [key]: value }));
  const submit = (text: string) => {
    const value = text.trim();
    if (!value) return;
    remember();
    setQuery(value);
    setSearchText(value);
    if (!prefs.incognito)
      setRecentSearch((v) =>
        [value, ...v.filter((t) => t !== value)].slice(0, 6),
      );
    setSection("search");
    setSuggest(false);
  };
  const open = (video: Video) => {
    remember();
    setCurrent(video);
    setPrevious(section);
    setSection("player");
    if (!prefs.incognito)
      setWatched((rows) => [video, ...rows.filter((v) => v.id !== video.id)]);
  };
  const suggestions = useMemo(
    () =>
      [...recentSearch, ...repository.recommendations().map((v) => v.title)]
        .filter(
          (s, i, a) =>
            a.indexOf(s) === i &&
            (!searchText || s.toLowerCase().includes(searchText.toLowerCase())),
        )
        .slice(0, 6),
    [searchText, recentSearch],
  );
  const content = useMemo(() => {
    const items =
      section === "search"
        ? repository.search(query)
        : repository.recommendations();
    return items.filter(
      (v) =>
        !prefs.blocked.includes(v.creator) &&
        !prefs.filters.some((t) => v.title.includes(t)),
    );
  }, [section, query, prefs.blocked, prefs.filters]);
  const textItems = historyTab === "专栏" ? sampleArticles : sampleNotes;
  const selectSetting = (category: string) => {
    remember();
    setSettingsTab(category);
    setArticle(null);
  };
  const folderVideos = (name: string) =>
    name === "默认收藏夹"
      ? repository.recommendations().filter((v) => saved.includes(v.id))
      : name === "值得再看"
        ? repository.recommendations().slice(6, 9)
        : name === "影像与生活"
          ? repository.recommendations().slice(9, 12)
          : [];
  const libraryVideos = (reverse ? [...watched].reverse() : watched).filter(
    (v) => v.title.includes(librarySearch),
  );
  function renderTextRows(items: typeof sampleArticles) {
    return (
      <div className="text-list">
        {items.map((item, i) => (
          <button
            key={item.id}
            className="text-entry"
            onClick={() => setArticle(item)}
          >
            <span className="entry-icon">
              <Icon name={i % 2 ? "list" : "info"} />
            </span>
            <span>
              <strong>{item.title}</strong>
              <small>{item.author}</small>
            </span>
            <Icon name="arrow_left" />
          </button>
        ))}
      </div>
    );
  }
  function row(label: string, control: React.ReactNode) {
    return (
      <div className="setting-row">
        <span>{label}</span>
        {control}
      </div>
    );
  }
  function select(key: "quality" | "speed", options: string[]) {
    return (
      <select
        aria-label={key === "quality" ? "默认画质" : "播放速度"}
        value={prefs[key]}
        onChange={(e) => change(key, e.target.value)}
      >
        {options.map((v) => (
          <option key={v}>{v}</option>
        ))}
      </select>
    );
  }

  return (
    <div className={`app ${rail ? "rail-open" : ""}`}>
      <Sidebar
        open={rail}
        section={section}
        items={navItems}
        onToggle={() => setRail((v) => !v)}
        onClose={() => setRail(false)}
        onNavigate={go}
      />

      <div className="workspace">
        {section === "home" && (
          <header className="home-header">
            <div className="search-box" ref={searchBox}>
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  submit(searchText);
                }}
              >
                <input
                  aria-label="搜索视频"
                  value={searchText}
                  onFocus={() => setSuggest(true)}
                  onChange={(e) => {
                    setSearchText(e.target.value);
                    setSuggest(true);
                  }}
                  onKeyDown={(e) => {
                    if (e.key === "Escape") setSuggest(false);
                  }}
                />
                <button aria-label="搜索" type="submit">
                  <Icon name="search" />
                </button>
              </form>
              {suggest && suggestions.length > 0 && (
                <div
                  className="suggestions"
                  role="listbox"
                  aria-label="搜索建议"
                >
                  {suggestions.map((t) => (
                    <button
                      key={t}
                      role="option"
                      aria-selected="false"
                      onClick={() => submit(t)}
                    >
                      <Icon name="search" />
                      <span>{t}</span>
                      <Icon name="arrow_left" />
                    </button>
                  ))}
                </div>
              )}
            </div>
          </header>
        )}
        <main
          ref={viewport}
          className={`main ${section === "home" ? "home-main" : ""}`}
          onScroll={() => {
            if (viewport.current)
              positions.current[screenKey] = viewport.current.scrollTop;
          }}
        >
          <div
            className={`content ${section === "player" ? "player-content" : ""}`}
          >
            {article ? (
              <section className="reader">
                <button
                  className="text-button"
                  onClick={() => setArticle(null)}
                >
                  <Icon name="arrow_left" />
                  返回列表
                </button>
                <h1>{article.title}</h1>
                <p>{article.body}</p>
              </section>
            ) : (
              <>
                {(section === "home" || section === "search") && (
                  <>
                    {section === "search" && (
                      <div className="page-toolbar">
                        <h1>“{query}”的搜索结果</h1>
                        <Tool
                          icon="close"
                          label="返回首页"
                          onClick={() => go("home")}
                        />
                      </div>
                    )}
                    {content.length ? (
                      <div className="video-grid">
                        {content.map((v) => (
                          <VideoCard key={v.id} video={v} onOpen={open} />
                        ))}
                      </div>
                    ) : (
                      <div className="empty">
                        <Icon name="search" />
                        <h2>没有找到相关视频</h2>
                        <button
                          className="secondary"
                          onClick={() => go("home")}
                        >
                          重新搜索
                        </button>
                      </div>
                    )}
                  </>
                )}
                {section === "profile" && (
                  <section className="profile-page">
                    <div className="profile-head">
                      <div className="avatar">
                        {author?.slice(0, 1) || "木"}
                      </div>
                      <div>
                        <h1>{author || "演示账号"}</h1>
                        <div className="profile-meta">
                          {author ? "创作者主页" : "Lv. 5"}
                          <span /> {author ? "视频与创作" : "硬币 128"}
                        </div>
                      </div>
                      {author && (
                        <button
                          className="secondary"
                          onClick={() => setAuthor(null)}
                        >
                          我的关注
                        </button>
                      )}
                    </div>
                    <div className="profile-line" />
                    <div className="follow-count">
                      <strong>
                        {author
                          ? repository
                              .recommendations()
                              .filter((v) => v.creator === author).length
                          : followed.length}
                      </strong>
                      <span>{author ? "投稿视频" : "关注数"}</span>
                    </div>
                    {author ? (
                      <div className="video-grid">
                        {repository
                          .recommendations()
                          .filter((v) => v.creator === author)
                          .map((v) => (
                            <VideoCard key={v.id} video={v} onOpen={open} />
                          ))}
                      </div>
                    ) : (
                      <div className="follow-list">
                        {followed.map((u, i) => (
                          <div className="follow-row" key={u.id}>
                            <button
                              className="follow-main"
                              onClick={() => setAuthor(u.name)}
                            >
                              <span className={`avatar small tone-${i % 4}`}>
                                {u.name.slice(0, 1)}
                              </span>
                              <span>
                                <strong>{u.name}</strong>
                                <small>{u.description}</small>
                              </span>
                            </button>
                            <button
                              className="following"
                              onClick={() =>
                                setFollowed((f) =>
                                  f.filter((v) => v.id !== u.id),
                                )
                              }
                            >
                              已关注
                              <Icon name="check" />
                            </button>
                            <Tool
                              icon="more"
                              label={`屏蔽 ${u.name}`}
                              onClick={() => {
                                change("blocked", [...prefs.blocked, u.name]);
                                setFollowed((f) =>
                                  f.filter((v) => v.id !== u.id),
                                );
                                notify("已加入黑名单");
                              }}
                            />
                          </div>
                        ))}
                      </div>
                    )}
                  </section>
                )}
                {section === "history" && (
                  <>
                    <div className="library-toolbar">
                      <Tabs
                        value={historyTab}
                        onChange={(t) => {
                          remember();
                          setHistoryTab(t);
                        }}
                      />
                      <div className="tools">
                        <Tool
                          icon="sort"
                          label="反转记录顺序"
                          active={reverse}
                          onClick={() => setReverse((v) => !v)}
                        />
                        <Tool
                          icon="search"
                          label="搜索记录"
                          active={showLibrarySearch}
                          onClick={() => setShowLibrarySearch((v) => !v)}
                        />
                        <Tool
                          icon="trash"
                          label="清空视频记录"
                          onClick={() => {
                            setWatched([]);
                            notify("演示视频记录已清空");
                          }}
                        />
                      </div>
                    </div>
                    {showLibrarySearch && (
                      <div className="library-search">
                        <Icon name="search" />
                        <input
                          autoFocus
                          aria-label="搜索记录内容"
                          value={librarySearch}
                          onChange={(e) => setLibrarySearch(e.target.value)}
                        />
                      </div>
                    )}
                    {historyTab === "视频" ? (
                      libraryVideos.length ? (
                        <div className="history-list">
                          {libraryVideos.map((v) => (
                            <div className="history-row" key={v.id}>
                              <button
                                className="history-open"
                                onClick={() => open(v)}
                              >
                                <img src={v.cover} alt="" />
                                <span>
                                  <strong>{v.title}</strong>
                                  <small>{v.creator}</small>
                                  <span className="viewed-progress">
                                    <i />
                                  </span>
                                </span>
                              </button>
                              <span className="history-time">已看至 02:18</span>
                              <Tool
                                icon="close"
                                label={`删除记录 ${v.title}`}
                                onClick={() =>
                                  setWatched((rows) =>
                                    rows.filter((i) => i.id !== v.id),
                                  )
                                }
                              />
                            </div>
                          ))}
                        </div>
                      ) : (
                        <div className="empty">
                          <Icon name="clock" />
                          <h2>暂无视频记录</h2>
                          <button
                            className="secondary"
                            onClick={() => go("home")}
                          >
                            去看看视频
                          </button>
                        </div>
                      )
                    ) : (
                      renderTextRows(
                        textItems.filter((t) =>
                          t.title.includes(librarySearch),
                        ),
                      )
                    )}
                  </>
                )}
                {section === "favorites" && (
                  <>
                    <div className="library-toolbar">
                      <Tabs
                        value={favoriteTab}
                        onChange={(t) => {
                          remember();
                          setFavoriteTab(t);
                          setFolder(null);
                        }}
                      />
                      <div className="tools">
                        <Tool
                          icon="plus"
                          label="新建收藏夹"
                          onClick={() => setEditFolders((v) => !v)}
                        />
                        <Tool
                          icon="sort"
                          label="反转收藏夹顺序"
                          onClick={() => setFolders((v) => [...v].reverse())}
                        />
                        <Tool
                          icon="search"
                          label="搜索收藏"
                          active={showLibrarySearch}
                          onClick={() => setShowLibrarySearch((v) => !v)}
                        />
                      </div>
                    </div>
                    {showLibrarySearch && (
                      <div className="library-search">
                        <Icon name="search" />
                        <input
                          autoFocus
                          aria-label="搜索收藏内容"
                          value={librarySearch}
                          onChange={(e) => setLibrarySearch(e.target.value)}
                        />
                      </div>
                    )}
                    {editFolders && (
                      <form
                        className="inline-input folder-input"
                        onSubmit={(e) => {
                          e.preventDefault();
                          if (newFolder.trim()) {
                            if (folders.includes(newFolder.trim())) {
                              notify("已有同名收藏夹");
                              return;
                            }
                            setFolders((f) => [...f, newFolder.trim()]);
                            setNewFolder("");
                            setEditFolders(false);
                          }
                        }}
                      >
                        <input
                          autoFocus
                          aria-label="新收藏夹名称"
                          value={newFolder}
                          onChange={(e) => setNewFolder(e.target.value)}
                        />
                        <button
                          className="primary"
                          disabled={!newFolder.trim()}
                        >
                          创建
                        </button>
                        <button
                          type="button"
                          className="secondary"
                          onClick={() => setEditFolders(false)}
                        >
                          取消
                        </button>
                      </form>
                    )}
                    {favoriteTab === "视频" ? (
                      folder ? (
                        <>
                          <div className="folder-heading">
                            <button
                              className="text-button"
                              onClick={() => setFolder(null)}
                            >
                              <Icon name="arrow_left" />
                              全部收藏
                            </button>
                            <h2>{folder}</h2>
                          </div>
                          <div className="video-grid">
                            {folderVideos(folder).map((v) => (
                              <VideoCard key={v.id} video={v} onOpen={open} />
                            ))}
                          </div>
                          {!folderVideos(folder).length && (
                            <div className="empty">
                              <Icon name="folder" />
                              <h2>收藏夹还是空的</h2>
                              <button
                                className="secondary"
                                onClick={() => go("home")}
                              >
                                去看看视频
                              </button>
                            </div>
                          )}
                        </>
                      ) : (
                        <div className="folder-grid">
                          {folders
                            .filter((f) => f.includes(librarySearch))
                            .map((f, i) => (
                              <button
                                className="folder-card"
                                key={f}
                                onClick={() => {
                                  remember();
                                  setFolder(f);
                                }}
                              >
                                <div className="folder-cover">
                                  <img
                                    src={
                                      repository.recommendations()[i % 12].cover
                                    }
                                    alt=""
                                  />
                                  <span>
                                    <Icon name="folder" />
                                  </span>
                                </div>
                                <strong>{f}</strong>
                                <small>{folderVideos(f).length} 个视频</small>
                              </button>
                            ))}
                        </div>
                      )
                    ) : (
                      renderTextRows(
                        (favoriteTab === "专栏"
                          ? sampleArticles
                          : sampleNotes
                        ).filter((t) => t.title.includes(librarySearch)),
                      )
                    )}
                  </>
                )}
                {section === "downloads" && (
                  <section>
                    <div className="page-toolbar">
                      <h1>缓存</h1>
                      <span className="muted">演示任务</span>
                    </div>
                    <div className="download-list">
                      {tasks.length ? (
                        tasks.map((task) => (
                          <div className="download-row" key={task.video.id}>
                            <img src={task.video.cover} alt="" />
                            <div className="download-info">
                              <strong>{task.video.title}</strong>
                              <div className="progress-track">
                                <i style={{ width: `${task.progress}%` }} />
                              </div>
                              <small>
                                {task.progress === 100
                                  ? "已完成"
                                  : task.paused
                                    ? "已暂停"
                                    : `缓存进度 ${task.progress}%`}
                              </small>
                            </div>
                            {task.progress === 100 ? (
                              <Tool
                                icon="play"
                                label="播放缓存预览"
                                onClick={() => open(task.video)}
                              />
                            ) : (
                              <Tool
                                icon={task.paused ? "play" : "pause"}
                                label={task.paused ? "继续缓存" : "暂停缓存"}
                                onClick={() =>
                                  setTasks((items) =>
                                    items.map((i) =>
                                      i.video.id === task.video.id
                                        ? { ...i, paused: !i.paused }
                                        : i,
                                    ),
                                  )
                                }
                              />
                            )}
                            <Tool
                              icon="trash"
                              label={`删除缓存 ${task.video.title}`}
                              onClick={() =>
                                setTasks((items) =>
                                  items.filter(
                                    (i) => i.video.id !== task.video.id,
                                  ),
                                )
                              }
                            />
                          </div>
                        ))
                      ) : (
                        <div className="empty">
                          <Icon name="download" />
                          <h2>暂无缓存任务</h2>
                        </div>
                      )}
                    </div>
                  </section>
                )}
                {section === "settings" && (
                  <SettingsView
                    preferences={prefs}
                    onChange={change}
                    category={settingsTab}
                    onCategoryChange={selectSetting}
                    onReset={() => setPrefs(defaults)}
                    notify={notify}
                  />
                )}
                {section === "player" && current && (
                  <section>
                    <div className="player-heading">
                      <button
                        className="text-button"
                        onClick={() => go(previous)}
                      >
                        <Icon name="arrow_left" />
                        返回
                      </button>
                    </div>
                    <div className="player-layout">
                      <div>
                        <div className="video-stage">
                          <img src={current.cover} alt="" />
                          <div className="player-preview">
                            <Icon name="play" />
                            <strong>播放器交互预览</strong>
                            <span>视频源将在接入现有播放接口后启用</span>
                          </div>
                        </div>
                        <div className="player-toolbar">
                          <div className="player-quality">
                            {select("quality", [
                              "自动",
                              "1080P",
                              "720P",
                              "480P",
                            ])}
                            {select("speed", [
                              "0.75x",
                              "1.0x",
                              "1.25x",
                              "1.5x",
                              "2.0x",
                            ])}
                          </div>
                          <div className="tools">
                            <Tool
                              icon="folder"
                              label="收藏视频"
                              active={saved.includes(current.id)}
                              onClick={() => {
                                setSaved((v) =>
                                  v.includes(current.id)
                                    ? v.filter((id) => id !== current.id)
                                    : [...v, current.id],
                                );
                                notify(
                                  saved.includes(current.id)
                                    ? "已取消收藏"
                                    : "已加入默认收藏夹",
                                );
                              }}
                            />
                            <Tool
                              icon="download"
                              label="添加演示缓存"
                              onClick={() => {
                                if (
                                  !tasks.some((t) => t.video.id === current.id)
                                )
                                  setTasks((t) => [
                                    ...t,
                                    {
                                      video: current,
                                      progress: 0,
                                      paused: true,
                                    },
                                  ]);
                                notify("已添加演示缓存任务");
                              }}
                            />
                          </div>
                        </div>
                        <h1 className="video-title">{current.title}</h1>
                        <button
                          className="creator-link"
                          onClick={() => {
                            setAuthor(current.creator);
                            go("profile");
                          }}
                        >
                          <span className="avatar tiny">
                            {current.creator.slice(0, 1)}
                          </span>
                          {current.creator}
                        </button>
                        <p className="video-description">
                          {current.description}
                        </p>
                      </div>
                      <div className="related">
                        <h2>相关推荐</h2>
                        {repository
                          .recommendations()
                          .filter((v) => v.id !== current.id)
                          .slice(0, 5)
                          .map((v) => (
                            <button
                              key={v.id}
                              className="related-card"
                              onClick={() => setCurrent(v)}
                            >
                              <img src={v.cover} alt="" />
                              <span>{v.title}</span>
                            </button>
                          ))}
                      </div>
                    </div>
                  </section>
                )}
              </>
            )}
          </div>
        </main>
      </div>
      {message && (
        <div className="toast" role="status">
          {message}
        </div>
      )}
    </div>
  );
}
