import {useScreenActive} from "./ScreenActivity";
import {CachedPoster} from './CachedPoster';
import { useEffect, useRef, useState } from "react";
import { folderCover, cachedFolderCover } from "../canvasApi";
import { Icon } from "./ui";
export function FolderArt({
  folder,
}: {
  folder: { id: number; cover: string; count: number };
}) {
  const active=useScreenActive();
  const ref = useRef<HTMLDivElement>(null),
    [cover, setCover] = useState(folder.cover || cachedFolderCover(folder.id)),
    [failed, setFailed] = useState(false);
  useEffect(() => {
    setCover(folder.cover || cachedFolderCover(folder.id));
    setFailed(false);
  }, [folder.id, folder.cover]);
  useEffect(() => {
    if (!active || cover || !folder.count || !ref.current) return;
    const abort=new AbortController();
    let live = true;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          observer.disconnect();
          folderCover(folder.id,abort.signal)
            .then((url) => {
              if (live) setCover(url);
            })
            .catch(() => {});
        }
      },
      { root: ref.current.closest(".canvas-scroll"), rootMargin: "40px" },
    );
    observer.observe(ref.current);
    return () => {
      live = false;
      abort.abort();
      observer.disconnect();
    };
  }, [active,folder.id, folder.count, cover]);
  return (
    <div ref={ref} className="canvas-folder-cover">
      {cover && !failed ? (
        <CachedPoster key={cover} src={cover} className="canvas-folder-poster canvas-poster" onError={()=>{setFailed(true);setCover('')}}/>      ) : (
        <Icon name="folder" />
      )}
      <span className="canvas-folder-count">{folder.count} 个视频</span>
    </div>
  );
}
