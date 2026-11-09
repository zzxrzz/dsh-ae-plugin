/**
 * @dsh-external/dsh-ae-plugin
 *
 * 唯一职责：把随包技能 `ae-video-automation` 注册进 DSH 的 skills 注册表。
 * 本插件不含工具面（AE 的自动化通道是 ExtendScript + PowerShell，由技能文档描述）。
 *
 * 注册方式与 @dsh-external/dsh-blender-plugin 一致：
 *   - rank = 600（BUNDLED_SKILL_RANK）；用户自己装在 ~/.dsh/skills 的副本 rank 400，优先级更高。
 *   - 只依赖 `ctx.skills.registerProvider` 这一稳定接口 + 纯文本 frontmatter 解析，不 import 宿主包。
 *   - 注册失败只告警，不影响插件加载。
 */
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const SKILL_NAME = 'ae-video-automation'
const PROVIDER_NAME = 'dsh-ae-plugin'
const BUNDLED_SKILL_RANK = 600
const SKILL_DIR = fileURLToPath(new URL('../skills/ae-video-automation/', import.meta.url))

let cache
let warned = false

/** 解析 SKILL.md 的 YAML frontmatter（只取 name/description，不引 yaml 依赖）。 */
function parseSkillFrontmatter(raw) {
  const m = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/.exec(raw)
  if (!m) return { meta: {}, body: raw }
  const meta = {}
  let key = ''
  for (const line of m[1].split(/\r?\n/)) {
    const kv = /^([A-Za-z0-9_-]+):\s*(.*)$/.exec(line)
    if (kv) {
      key = kv[1]
      let v = kv[2].trim()
      if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1)
      meta[key] = v
      continue
    }
    // YAML 折叠/多行 continuation：缩进行并进上一个 key
    if (key && /^\s+\S/.test(line)) meta[key] = (meta[key] ? meta[key] + ' ' : '') + line.trim()
  }
  return { meta, body: raw.slice(m[0].length) }
}

function readBundledSkill() {
  if (cache !== undefined) return cache
  try {
    const raw = readFileSync(path.join(SKILL_DIR, 'SKILL.md'), 'utf8')
    const { meta, body } = parseSkillFrontmatter(raw)
    const name = String(meta.name || '').trim()
    const description = String(meta.description || '').trim()
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name) || !description) {
      cache = null
      return null
    }
    cache = { name, description, content: body }
    return cache
  } catch {
    cache = null
    return null
  }
}

function createProvider() {
  const skill = readBundledSkill()
  if (!skill) return null
  const skillFile = path.join(SKILL_DIR, 'SKILL.md')
  const resourceBase = { kind: 'directory', path: SKILL_DIR.split(path.sep).join('/') }
  return {
    name: PROVIDER_NAME,
    // 必须是 async：宿主 lookup 在带 signal 时会对返回值直接 .then(...)
    list: async () => [{
      name: skill.name,
      description: skill.description,
      invocation: { modelInvocable: true, userInvocable: true },
      source: 'bundled',
      provider: PROVIDER_NAME,
      rank: BUNDLED_SKILL_RANK,
      resourceBase,
      path: skillFile,
      locator: skillFile,
    }],
    get: async () => ({
      name: skill.name,
      description: skill.description,
      invocation: { modelInvocable: true, userInvocable: true },
      source: 'bundled',
      provider: PROVIDER_NAME,
      resourceBase,
      path: skillFile,
      content: skill.content,
    }),
  }
}

function registerBundledSkill(ctx) {
  const provider = createProvider()
  if (provider === null) {
    if (!warned) {
      warned = true
      try { ctx?.logger?.warn?.(`bundled skill 未注册：skills/${SKILL_NAME}/SKILL.md 缺失或 frontmatter 不合法`) } catch {}
    }
    return
  }
  const mount = (c) => {
    try {
      c.skills.registerProvider(() => provider)
    } catch (e) {
      try { ctx?.logger?.warn?.('bundled skill 注册失败：' + String((e && e.message) || e)) } catch {}
    }
  }
  try {
    if (typeof ctx?.inject === 'function') ctx.inject(['skills'], mount)
    else if (ctx?.skills && typeof ctx.skills.registerProvider === 'function') mount(ctx)
  } catch (e) {
    try { ctx?.logger?.warn?.('bundled skill 挂载失败：' + String((e && e.message) || e)) } catch {}
  }
}

export function apply(ctx, _config) {
  registerBundledSkill(ctx)
}

export const inject = ['skills']
