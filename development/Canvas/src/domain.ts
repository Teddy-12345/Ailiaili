import feed from "./feed.json";
export type Section =
  | "home"
  | "featured"
  | "profile"
  | "history"
  | "favorites"
  | "downloads"
  | "settings"
  | "search"
  | "player";
export type Video = (typeof feed)[number];
export type Category = "视频" | "专栏" | "笔记";
export type Theme = "light" | "dark" | "system";
export interface Preferences {
  theme: Theme;
  incognito: boolean;
  quality: string;
  speed: string;
  autoplay: boolean;
  hardware: boolean;
  subtitles: boolean;
  gestures: boolean;
  doubleTap: boolean;
  volume: number;
  buffer: number;
  proxy: boolean;
  filters: string[];
  blocked: string[];
}
export const defaults: Preferences = {
  theme: "light",
  incognito: false,
  quality: "1080P",
  speed: "1.0x",
  autoplay: true,
  hardware: true,
  subtitles: true,
  gestures: true,
  doubleTap: true,
  volume: 70,
  buffer: 64,
  proxy: false,
  filters: [],
  blocked: [],
};
// Repository boundary: UI state never depends on Flutter widgets or GetX routes.
// The first adapter is deterministic preview data. A live adapter can implement this contract.
export interface VideoRepository {
  recommendations(): Video[];
  search(query: string): Video[];
  following(): {
    id: string;
    name: string;
    description: string;
    count: number;
  }[];
}
export class PreviewRepository implements VideoRepository {
  recommendations() {
    return feed;
  }
  search(query: string) {
    const q = query.trim().toLowerCase();
    return feed.filter((v) => (v.title + v.creator).toLowerCase().includes(q));
  }
  following() {
    return feed
      .slice(0, 8)
      .map((v, i) => ({
        id: v.id,
        name: v.creator,
        description: [
          "记录生活里的小发现",
          "分享喜欢的视频与故事",
          "认真做好每一次创作",
        ][i % 3],
        count: 48 + i * 17,
      }));
  }
}
export const repository: VideoRepository = new PreviewRepository();
export const sampleArticles = [
  {
    id: "a1",
    title: "把日常的片段，拍成一段好故事",
    author: "生活记录",
    body: "从观察光线开始，记录身边熟悉的事物。故事不一定宏大，也可以只是平常的一天。",
  },
  {
    id: "a2",
    title: "关于视频画质，你可能关心的几个问题",
    author: "影像手记",
    body: "分辨率、码率与设备屏幕共同影响观看体验。选择适合当前网络和设备的画质即可。",
  },
  {
    id: "a3",
    title: "走出去，看一看镜头之外的世界",
    author: "旅行札记",
    body: "提前规划路线，带上轻便的设备，给沿途意外的风景留一点时间。",
  },
];
export const sampleNotes = [
  {
    id: "n1",
    title: "拍摄笔记：自然光与构图",
    author: "我的笔记",
    body: "傍晚的光线更柔和。主体不必总在画面正中央，注意保留环境与呼吸空间。",
  },
  {
    id: "n2",
    title: "稍后复习的剪辑技巧",
    author: "我的笔记",
    body: "先整理素材，再组织节奏。转场服务于内容，声音也可以带动叙事。",
  },
];
export const duration = (n: number) =>
  `${Math.floor(n / 60)}:${String(n % 60).padStart(2, "0")}`;
export const views = (n: number) =>
  n >= 10000 ? `${(n / 10000).toFixed(1)}万` : String(n);
