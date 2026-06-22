/**
 * JSPsych ParameterType constants for use in custom plugins.
 * Import this instead of importing from 'jspsych' so your plugin
 * doesn't need jspsych as a build-time dependency.
 *
 * Usage:
 *   import { ParameterType } from '../types.js';
 */
export const ParameterType = {
  BOOL: 0,
  STRING: 1,
  INT: 2,
  FLOAT: 3,
  FUNCTION: 4,
  KEY: 5,
  KEYS: 6,
  SELECT: 7,
  HTML_STRING: 8,
  IMAGE: 9,
  AUDIO: 10,
  VIDEO: 11,
  OBJECT: 12,
  COMPLEX: 13,
  TIMELINE: 14,
};
