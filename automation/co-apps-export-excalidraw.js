#!/usr/bin/env node
// Generates a bird's eye view diagram of the 5 CO Apps projects.
// Usage:
//   node co-apps-export-excalidraw.js                              # upload to excalidraw.com
//   node co-apps-export-excalidraw.js --github output.excalidraw   # write to file

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const githubIdx = args.indexOf('--github');
const githubMode = githubIdx >= 0;
const githubOutFile = githubMode ? args[githubIdx + 1] : null;

async function main() {
  // Load repo status
  const statusFile = path.join(process.env.HOME, '.local/share/co-apps-meeting/repo_status.json');
  let repos;
  try {
    repos = JSON.parse(fs.readFileSync(statusFile, 'utf8'));
  } catch {
    repos = [
      { name: 'hourhive-buddy', desc: 'VA Analytics & Integrations', contributor: 'Jilian Garette', status: 'active', issues: 0, pushed: 'unknown' },
      { name: 'catalyst-opus', desc: 'Task Management Platform', contributor: 'Warren Apit', status: 'active', issues: 74, pushed: 'unknown' },
      { name: 'outsource-sales-portal-magic', desc: 'Sales Portal', contributor: 'Lovable Bot', status: 'active', issues: 0, pushed: 'unknown' },
      { name: 'catalyst-refresh-glow', desc: 'Marketing Website', contributor: 'Lovable Bot', status: 'active', issues: 0, pushed: 'unknown' },
      { name: 'partner-hub-40', desc: 'Partner Hub', contributor: 'Lovable Bot', status: 'stale', issues: 0, pushed: 'unknown' },
      { name: 'tavus-talent-spotter-15b98171', desc: 'Recruitment Portal', contributor: 'Jilian Garette', status: 'active', issues: 0, pushed: 'unknown' },
    ];
  }

  let outstanding = 0;
  try {
    const state = JSON.parse(fs.readFileSync(
      path.join(process.env.HOME, '.local/share/co-apps-meeting/state.json'), 'utf8'));
    outstanding = (state.action_items || []).filter(a => a.status !== 'done').length;
  } catch {}

  const today = new Date().toISOString().slice(0, 10);
  const elements = [];
  let idCounter = 0;

  function uid() { return 'el_' + (++idCounter) + '_' + Math.random().toString(36).slice(2, 8); }

  function addRect(x, y, w, h, text, bg, stroke, fontSize = 16) {
    const rectId = uid();
    const textId = uid();
    const lines = text.split('\n');
    const lineHeight = fontSize * 1.25;
    const textH = lines.length * lineHeight;

    elements.push({
      id: rectId, type: 'rectangle',
      x, y, width: w, height: h, angle: 0,
      strokeColor: stroke, backgroundColor: bg,
      fillStyle: 'solid', strokeWidth: 2, strokeStyle: 'solid',
      roughness: 1, opacity: 100,
      groupIds: [], frameId: null, index: 'a' + elements.length,
      roundness: { type: 3 },
      seed: Math.floor(Math.random() * 2147483647),
      version: 1, versionNonce: Math.floor(Math.random() * 2147483647),
      isDeleted: false, updated: Date.now(), link: null, locked: false,
      boundElements: [{ type: 'text', id: textId }],
    });

    elements.push({
      id: textId, type: 'text',
      x: x + 10, y: y + (h - textH) / 2, width: w - 20, height: textH, angle: 0,
      strokeColor: stroke, backgroundColor: 'transparent',
      fillStyle: 'solid', strokeWidth: 0, strokeStyle: 'solid',
      roughness: 0, opacity: 100,
      groupIds: [], frameId: null, index: 'a' + elements.length,
      roundness: null,
      seed: Math.floor(Math.random() * 2147483647),
      version: 1, versionNonce: Math.floor(Math.random() * 2147483647),
      isDeleted: false, updated: Date.now(), link: null, locked: false,
      boundElements: null,
      text, originalText: text,
      fontSize, fontFamily: 1,
      textAlign: 'center', verticalAlign: 'middle',
      containerId: rectId, autoResize: true, lineHeight: 1.25,
    });
    return rectId;
  }

  function addDiamond(x, y, w, h, text, bg, stroke, fontSize = 12) {
    const dId = uid();
    const tId = uid();
    const lines = text.split('\n');
    const lineHeight = fontSize * 1.25;
    const textH = lines.length * lineHeight;

    elements.push({
      id: dId, type: 'diamond',
      x, y, width: w, height: h, angle: 0,
      strokeColor: stroke, backgroundColor: bg,
      fillStyle: 'solid', strokeWidth: 2, strokeStyle: 'solid',
      roughness: 1, opacity: 100,
      groupIds: [], frameId: null, index: 'a' + elements.length,
      roundness: { type: 2 },
      seed: Math.floor(Math.random() * 2147483647),
      version: 1, versionNonce: Math.floor(Math.random() * 2147483647),
      isDeleted: false, updated: Date.now(), link: null, locked: false,
      boundElements: [{ type: 'text', id: tId }],
    });

    elements.push({
      id: tId, type: 'text',
      x: x + w * 0.2, y: y + (h - textH) / 2, width: w * 0.6, height: textH, angle: 0,
      strokeColor: stroke, backgroundColor: 'transparent',
      fillStyle: 'solid', strokeWidth: 0, strokeStyle: 'solid',
      roughness: 0, opacity: 100,
      groupIds: [], frameId: null, index: 'a' + elements.length,
      roundness: null,
      seed: Math.floor(Math.random() * 2147483647),
      version: 1, versionNonce: Math.floor(Math.random() * 2147483647),
      isDeleted: false, updated: Date.now(), link: null, locked: false,
      boundElements: null,
      text, originalText: text,
      fontSize, fontFamily: 1,
      textAlign: 'center', verticalAlign: 'middle',
      containerId: dId, autoResize: true, lineHeight: 1.25,
    });
    return dId;
  }

  // App details
  const appDetails = {
    'hourhive-buddy': {
      desc: 'VA Management & Analytics',
      features: ['Discord/Slack webhooks', 'VA leave requests', 'Productivity analytics', 'Notification system'],
      stack: 'React + Supabase',
    },
    'catalyst-opus': {
      desc: 'Task Management Platform',
      features: ['Task CRUD + priorities', 'Org member invitations', 'Resend email integration', 'Routines system'],
      stack: 'React + Supabase',
    },
    'outsource-sales-portal-magic': {
      desc: 'Sales Portal',
      features: ['Role-based access', 'Email notifications', 'Account management', 'Sales pipeline'],
      stack: 'React + Supabase',
    },
    'catalyst-refresh-glow': {
      desc: 'Marketing Website',
      features: ['SEO optimized pages', 'FAQ sections', 'Bookkeeping VA pages', 'Lead capture'],
      stack: 'React + Vite',
    },
    'partner-hub-40': {
      desc: 'Partner Hub',
      features: ['Google Sign-in', 'Magic link auth', 'Partner dashboard', 'Resource sharing'],
      stack: 'React + Supabase',
    },
    'tavus-talent-spotter-15b98171': {
      desc: 'Recruitment Portal',
      features: ['Candidate intake + screening', 'Tavus AI video interviews', 'Hiring pipeline', 'Recruiter workflow'],
      stack: 'React + Supabase',
    },
  };

  // Colors
  const C = {
    active: ['#d3f9d8', '#1e7e34'],
    stale: ['#ffe3e3', '#e03131'],
    hdr: ['#d0ebff', '#1864ab'],
    shared: ['#e9ecef', '#495057'],
    owner: ['#fff9db', '#e67700'],
    meeting: ['#f3d9fa', '#9c36b5'],
  };

  // ── Title ──
  addRect(180, 20, 640, 60, 'CO Apps -- Bird\'s Eye View', ...C.hdr, 24);
  addRect(180, 90, 640, 30, `Owner: Leo Tan | Updated: ${today} | ${outstanding} action items | Weekly meeting: Tue 4-5 PM SGT`, '#f8f9fa', '#868e96', 10);

  // ── App cards (2 rows) ──
  const cardW = 300;
  const cardH = 200;
  const gap = 30;
  const startX = 30;
  const row1Y = 160;
  const row2Y = row1Y + cardH + gap;

  const positions = [
    [startX, row1Y],
    [startX + cardW + gap, row1Y],
    [startX + (cardW + gap) * 2, row1Y],
    [startX, row2Y],
    [startX + cardW + gap, row2Y],
    [startX + (cardW + gap) * 2, row2Y],
  ];

  repos.forEach((repo, i) => {
    const [x, y] = positions[i];
    const details = appDetails[repo.name] || { desc: '', features: [], stack: '' };
    const [bg, stroke] = repo.status === 'active' ? C.active : C.stale;
    const statusTag = repo.status === 'active' ? 'ACTIVE' : 'STALE';

    // App name header
    addRect(x, y, cardW, 45, repo.name, bg, stroke, 16);

    // Status badge
    const badgeBg = repo.status === 'active' ? '#b2f2bb' : '#ffc9c9';
    addRect(x + cardW - 80, y + 5, 70, 22, statusTag, badgeBg, stroke, 10);

    // Description
    addRect(x, y + 50, cardW, 30, details.desc, '#f8f9fa', '#495057', 12);

    // Features list
    const featText = details.features.map(f => '- ' + f).join('\n');
    addRect(x, y + 85, cardW, 70, featText, '#ffffff', '#dee2e6', 10);

    // Footer: contributor + issues + stack
    const issueStr = repo.issues > 0 ? ` | ${repo.issues} open issues` : '';
    const footerText = `${repo.contributor}${issueStr}\n${details.stack} | Last push: ${repo.pushed || 'unknown'}`;
    addRect(x, y + 160, cardW, 40, footerText, '#f8f9fa', '#868e96', 9);
  });

  // ── Shared Infrastructure ──
  const infraY = row2Y + cardH + gap + 20;

  addRect(180, infraY, 640, 35, 'Shared Infrastructure', ...C.shared, 14);

  addRect(30, infraY + 50, 180, 45, 'Supabase\nAuth + Database', '#d0ebff', '#1864ab', 11);
  addRect(230, infraY + 50, 180, 45, 'Lovable / GPT Engineer\nAI-assisted development', '#e5dbff', '#7048e8', 11);
  addRect(430, infraY + 50, 180, 45, 'Vercel\nDeployment', '#d3f9d8', '#1e7e34', 11);
  addRect(630, infraY + 50, 180, 45, 'GitHub\nleotansingapore/*', '#e9ecef', '#495057', 11);

  // ── Weekly Meeting Automation ──
  const meetY = infraY + 120;
  addRect(180, meetY, 640, 35, 'Weekly Meeting Automation (Tuesdays)', ...C.meeting, 14);

  addRect(30, meetY + 50, 250, 40, '3:00 PM -- Reminder sent to Lark\nwith Google Meet link', '#f3d9fa', '#9c36b5', 10);
  addRect(300, meetY + 50, 250, 40, '3:30 PM -- Agenda posted to Lark\nwhat each team worked on this week', '#f3d9fa', '#9c36b5', 10);
  addRect(570, meetY + 50, 250, 40, '5:30 PM -- Meeting notes analysed\naction items become GitHub issues', '#f3d9fa', '#9c36b5', 10);

  // Build scene
  const scene = {
    type: 'excalidraw',
    version: 2,
    source: 'https://excalidraw.com',
    elements,
    appState: { viewBackgroundColor: '#ffffff' },
    files: {},
  };

  if (githubMode && githubOutFile) {
    fs.writeFileSync(githubOutFile, JSON.stringify(scene, null, 2));
    console.log(githubOutFile);
  } else {
    const sceneStr = JSON.stringify(scene);
    const key = await crypto.webcrypto.subtle.generateKey(
      { name: 'AES-GCM', length: 128 }, true, ['encrypt', 'decrypt']
    );
    const iv = crypto.randomBytes(12);
    const encrypted = await crypto.webcrypto.subtle.encrypt(
      { name: 'AES-GCM', iv }, key, Buffer.from(sceneStr)
    );
    const jwk = await crypto.webcrypto.subtle.exportKey('jwk', key);

    const res = await fetch('https://json.excalidraw.com/api/v2/post/', {
      method: 'POST',
      body: Buffer.concat([iv, Buffer.from(encrypted)]),
    });

    if (!res.ok) {
      console.error(`Upload failed: ${res.status}`);
      process.exit(1);
    }

    const result = await res.json();
    const shareUrl = `https://excalidraw.com/#json=${result.id},${jwk.k}`;
    const urlFile = path.join(process.env.HOME, '.local/share/co-apps-meeting/excalidraw_url.txt');
    fs.writeFileSync(urlFile, shareUrl);
    console.log(shareUrl);
  }
}

main().catch(err => {
  console.error(err.message);
  process.exit(1);
});
