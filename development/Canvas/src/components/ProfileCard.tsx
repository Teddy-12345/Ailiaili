import {thumbnailUrl} from "../mediaWork";
import { useState } from "react";
export type Profile = {
  mid?: number;
  name: string;
  face: string;
  sign?: string;
  topPhoto?: string;
  level?: number;
  currentExp?: number;
  nextExp?: number | string;
  vip?: boolean;
  vipLabel?: string;
  official?: string;
  following?: number;
  videos?: number;
  notice?: string;
};
export function ProfileCard({ profile, own=false }: { profile: Profile; own?:boolean }) {
  const [expanded, setExpanded] = useState(false);
  const hasExp =
    typeof profile.currentExp === "number" &&
    typeof profile.nextExp === "number" &&
    profile.nextExp > 0;
  return (
    <section
      className="profile-card"
      aria-label="个人资料"
    >
      <div className="profile-card-content">
        <img
          className="profile-card-avatar"
          src={profile.face ? thumbnailUrl(profile.face,true) : undefined}
          alt="头像"
          referrerPolicy="no-referrer"
        />
        <div className="profile-card-body">
          <div className="profile-card-line">
            <h1>{profile.name}</h1>
            {profile.level != null && (
              <span className="level-tag">LV{profile.level}</span>
            )}
            {hasExp && (
              <div className="profile-experience">
                <span>
                  {profile.currentExp}/{profile.nextExp}
                </span>
                <div>
                  <i
                    style={{
                      width: `${Math.min(100, (profile.currentExp! / (profile.nextExp as number)) * 100)}%`,
                    }}
                  />
                </div>
              </div>
            )}
            <span className={`vip-tag ${profile.vip ? "is-vip" : ""}`}>
              {profile.vipLabel || "大会员"}
            </span>
          </div>
          {profile.sign && (
            <div className={`profile-sign ${expanded ? "expanded" : ""}`}>
              <p>{profile.sign}</p>
              <button onClick={() => setExpanded((v) => !v)}>
                {expanded ? "收起" : "详情"}
              </button>
            </div>
          )}
          {profile.official && (
            <p className="profile-official">{profile.official}</p>
          )}
          {profile.notice && <p className="profile-notice">{profile.notice}</p>}
        </div>
        {own && profile.following != null && <div className="profile-follow-badge"><strong>{profile.following}</strong><span>关注数</span></div>}
      </div>
    </section>
  );
}
