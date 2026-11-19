import { isValidElement, useRef, useState } from "react";
import type { Preferences, Theme } from "../domain";
import { Icon, Toggle } from "../components/ui";
type Props = {
  preferences: Preferences;
  onChange: <K extends keyof Preferences>(
    key: K,
    value: Preferences[K],
  ) => void;
  category: string;
  onCategoryChange: (category: string) => void;
  onReset: () => void;
  notify: (text: string) => void;
};
export function SettingsView({
  preferences: prefs,
  onChange: change,

  onReset,
  notify,
}: Props) {
  const [keyword, setKeyword] = useState("");
  const [themePreview, setThemePreview] = useState<Theme | null>(null);
  const themePointer = useRef<number | null>(null),
    skipClick = useRef(false);
  const themeAt = (x: number, y: number, root: HTMLElement) => {
    const target = document
      .elementFromPoint(x, y)
      ?.closest<HTMLElement>("[data-theme-choice]");
    return target && root.contains(target)
      ? (target.dataset.themeChoice as Theme)
      : null;
  };

  function row(label: string, control: React.ReactNode) {
    const toggle =
      isValidElement<{ value: boolean; onChange: (value: boolean) => void }>(
        control,
      ) && control.type === Toggle
        ? control
        : null;
    return (
      <div
        className={`setting-row ${toggle ? "toggle-row" : ""}`}
        onClick={(event) => {
          if (
            toggle &&
            !(event.target as HTMLElement).closest("button,input,select")
          )
            toggle.props.onChange(!toggle.props.value);
        }}
      >
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
    <div className="settings-page">
      <h1>设置</h1>
      <div className="settings-layout">
        <div className="settings-content">
          {true && (
            <>
              <h2>外观</h2>
              <div
                className="themes"
                role="radiogroup"
                aria-label="主题"
                onPointerDown={(e) => {
                  if (e.pointerType !== "mouse") {
                    e.currentTarget.setPointerCapture(e.pointerId);
                    e.preventDefault();
                    themePointer.current = e.pointerId;
                    setThemePreview(
                      themeAt(e.clientX, e.clientY, e.currentTarget),
                    );
                  }
                }}
                onPointerMove={(e) => {
                  if (themePointer.current === e.pointerId)
                    setThemePreview(
                      themeAt(e.clientX, e.clientY, e.currentTarget),
                    );
                }}
                onPointerUp={(e) => {
                  if (themePointer.current === e.pointerId) {
                    const target = themeAt(
                      e.clientX,
                      e.clientY,
                      e.currentTarget,
                    );
                    if (target) change("theme", target);
                    themePointer.current = null;
                    setThemePreview(null);
                    skipClick.current = true;
                  }
                }}
                onPointerCancel={() => {
                  themePointer.current = null;
                  setThemePreview(null);
                  skipClick.current = false;
                }}
              >
                {(["light", "dark", "system"] as Theme[]).map((t, i) => (
                  <button
                    key={t}
                    data-theme-choice={t}
                    role="radio"
                    aria-checked={(themePreview || prefs.theme) === t}
                    onClick={(e) => {
                      if (skipClick.current && e.detail > 0) {
                        skipClick.current = false;
                        return;
                      }
                      change("theme", t);
                    }}
                  >
                    <div className={`theme-preview ${t}`}>
                      <div className="mini-window">
                        <span />
                        <div>
                          <i />
                          <i />
                          <i />
                          <i />
                        </div>
                      </div>
                      {(themePreview || prefs.theme) === t && (
                        <b>
                          <Icon name="check" />
                        </b>
                      )}
                    </div>
                    <span className="theme-label">
                      <i />
                      {["浅色", "深色", "跟随系统"][i]}
                    </span>
                  </button>
                ))}
              </div>
              <div className="settings-divider" />
              {row(
                "无痕模式",
                <Toggle
                  label="无痕模式"
                  value={prefs.incognito}
                  onChange={(v) => change("incognito", v)}
                />,
              )}
              <button
                className="setting-row clickable"
                onClick={() =>
                  document
                    .getElementById("block-settings")
                    ?.scrollIntoView({ behavior: "smooth" })
                }
              >
                <span>黑名单管理</span>
                <Icon name="arrow_left" />
              </button>
              {row(
                "默认画质",
                select("quality", ["自动", "1080P", "720P", "480P"]),
              )}
              {row(
                "播放速度",
                select("speed", ["0.75x", "1.0x", "1.25x", "1.5x", "2.0x"]),
              )}
            </>
          )}
          {true && (
            <>
              <h2>播放</h2>
              {row(
                "自动播放",
                <Toggle
                  label="自动播放"
                  value={prefs.autoplay}
                  onChange={(v) => change("autoplay", v)}
                />,
              )}
              {row(
                "默认画质",
                select("quality", ["自动", "1080P", "720P", "480P"]),
              )}
              {row(
                "播放速度",
                select("speed", ["0.75x", "1.0x", "1.25x", "1.5x", "2.0x"]),
              )}
              {row(
                "音量",
                <div className="range-control">
                  <input
                    aria-label="音量"
                    type="range"
                    min="0"
                    max="100"
                    value={prefs.volume}
                    onChange={(e) => change("volume", +e.target.value)}
                  />
                  <span>{prefs.volume}%</span>
                </div>,
              )}
            </>
          )}
          {true && (
            <>
              <h2>画面</h2>
              {row(
                "硬件解码",
                <Toggle
                  label="硬件解码"
                  value={prefs.hardware}
                  onChange={(v) => change("hardware", v)}
                />,
              )}
              {row(
                "显示字幕",
                <Toggle
                  label="显示字幕"
                  value={prefs.subtitles}
                  onChange={(v) => change("subtitles", v)}
                />,
              )}
              <h2 className="subheading">屏蔽关键词</h2>
              <form
                className="inline-input"
                onSubmit={(e) => {
                  e.preventDefault();
                  if (keyword.trim()) {
                    change("filters", [...prefs.filters, keyword.trim()]);
                    setKeyword("");
                  }
                }}
              >
                <input
                  aria-label="屏蔽关键词"
                  value={keyword}
                  onChange={(e) => setKeyword(e.target.value)}
                />
                <button className="secondary" disabled={!keyword.trim()}>
                  添加
                </button>
              </form>
              <div className="chips">
                {prefs.filters.map((k) => (
                  <button
                    key={k}
                    onClick={() =>
                      change(
                        "filters",
                        prefs.filters.filter((v) => v !== k),
                      )
                    }
                  >
                    {k}
                    <Icon name="close" />
                  </button>
                ))}
              </div>
            </>
          )}
          {true && (
            <>
              <h2>触摸与手势</h2>
              {row(
                "双击播放或暂停",
                <Toggle
                  label="双击播放或暂停"
                  value={prefs.doubleTap}
                  onChange={(v) => change("doubleTap", v)}
                />,
              )}
              {row(
                "滑动调节音量和亮度",
                <Toggle
                  label="滑动调节音量和亮度"
                  value={prefs.gestures}
                  onChange={(v) => change("gestures", v)}
                />,
              )}
              <p className="quiet-note">
                选项支持整行点击；拖动滑块时保持触摸位置，松手后确认。
              </p>
            </>
          )}
          {true && (
            <>
              <h2>网络</h2>
              {row(
                "使用系统代理",
                <Toggle
                  label="使用系统代理"
                  value={prefs.proxy}
                  onChange={(v) => change("proxy", v)}
                />,
              )}
              {row(
                "视频缓存",
                <div className="range-control">
                  <input
                    aria-label="视频缓存"
                    type="range"
                    min="32"
                    max="256"
                    step="16"
                    value={prefs.buffer}
                    onChange={(e) => change("buffer", +e.target.value)}
                  />
                  <span>{prefs.buffer} MB</span>
                </div>,
              )}
            </>
          )}
          {true && (
            <>
              <h2 id="block-settings">黑名单</h2>
              {prefs.blocked.length ? (
                prefs.blocked.map((name) => (
                  <div className="setting-row" key={name}>
                    <span>{name}</span>
                    <button
                      className="secondary"
                      onClick={() =>
                        change(
                          "blocked",
                          prefs.blocked.filter((n) => n !== name),
                        )
                      }
                    >
                      移除
                    </button>
                  </div>
                ))
              ) : (
                <div className="small-empty">
                  <Icon name="person" />
                  <span>没有屏蔽的用户</span>
                </div>
              )}
            </>
          )}
          {true && (
            <>
              <h2>哔哩哔哩 · 交互框架</h2>
              <p className="about-copy">
                这是电脑端前端原型。视频封面来自公开数据快照，个人、历史与收藏使用演示数据；尚未连接你的账户和播放接口。
              </p>
              <p className="about-copy">
                所有功能区在一个应用容器内切换，保留筛选和滚动位置。界面、状态与数据适配层分开，后续替换数据源即可接入实际业务。
              </p>
              <button
                className="secondary"
                onClick={() => {
                  onReset();
                  notify("已恢复默认设置");
                }}
              >
                恢复默认设置
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
