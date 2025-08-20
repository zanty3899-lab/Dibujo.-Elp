#!/usr/bin/env python3
"""Mechanic Avatar Generator

This module creates a simple animated mechanic avatar and exports the result
as an ``mp4`` video. The avatar is purposely stylised so it can be tweaked for
informational videos.

Features
--------
* Lip movement synchronised with an audio file.
* Three facial expressions: happy, serious and surprised.
* Simple arm gestures: rest, pointing and waving.
* Changeable clothing colour and background colour.
* Helmet and overall to emphasise the mechanical theme.

The script relies on ``pygame`` for drawing and ``moviepy`` for composing the
video.  Drawing is done on an off‑screen surface so no window is opened, which
makes the script suitable for automated video generation.
"""

from __future__ import annotations

import argparse
import math
import os
from typing import Callable, Tuple

import numpy as np
import pygame
from moviepy.audio.io.AudioFileClip import AudioFileClip
from moviepy.video.VideoClip import VideoClip

# ``pygame`` normally requires a windowing system.  The ``dummy`` video driver
# allows it to run headless which is ideal for CI environments.
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

# Basic colours
BLACK = (0, 0, 0)
SKIN = (255, 224, 189)
HELMET = (255, 215, 0)  # yellow safety helmet


def hex_to_rgb(value: str) -> Tuple[int, int, int]:
    """Convert ``#RRGGBB`` strings to ``(R, G, B)`` tuples."""

    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


class MechanicAvatar:
    """Draws a very simple mechanic avatar."""

    def __init__(
        self,
        width: int = 640,
        height: int = 480,
        clothing_color: Tuple[int, int, int] = (0, 102, 204),
        bg_color: Tuple[int, int, int] = (255, 255, 255),
        expression: str = "happy",
        arm_pose: str = "down",
    ) -> None:
        pygame.init()
        self.width = width
        self.height = height
        self.surface = pygame.Surface((width, height))
        self.clothing_color = clothing_color
        self.bg_color = bg_color
        self.expression = expression
        self.arm_pose = arm_pose

    # ------------------------------------------------------------------
    # Configuration helpers
    def set_expression(self, expression: str) -> None:
        self.expression = expression

    def set_arm_pose(self, arm_pose: str) -> None:
        self.arm_pose = arm_pose

    # ------------------------------------------------------------------
    # Drawing methods
    def _draw_body(self) -> None:
        center_x = self.width // 2
        # Torso
        pygame.draw.rect(
            self.surface,
            self.clothing_color,
            (center_x - 40, self.height // 2, 80, 100),
        )
        # Legs
        pygame.draw.rect(
            self.surface,
            self.clothing_color,
            (center_x - 40, self.height // 2 + 100, 30, 80),
        )
        pygame.draw.rect(
            self.surface,
            self.clothing_color,
            (center_x + 10, self.height // 2 + 100, 30, 80),
        )

    def _draw_arms(self, t: float) -> None:
        center_x = self.width // 2
        shoulder_y = self.height // 2 + 20
        arm_len = 60

        # Left arm resting
        left_shoulder = (center_x - 40, shoulder_y)
        left_end = (left_shoulder[0] - arm_len, shoulder_y + arm_len)
        pygame.draw.line(self.surface, SKIN, left_shoulder, left_end, 8)

        # Right arm animated
        right_shoulder = (center_x + 40, shoulder_y)
        if self.arm_pose == "wave":
            angle = math.radians(45 + 30 * math.sin(2 * math.pi * 2 * t))
        elif self.arm_pose == "point":
            angle = math.radians(0)
        else:  # down
            angle = math.radians(90)
        end_x = right_shoulder[0] + arm_len * math.cos(angle)
        end_y = right_shoulder[1] - arm_len * math.sin(angle)
        pygame.draw.line(self.surface, SKIN, right_shoulder, (end_x, end_y), 8)

    def _draw_head(self, mouth_open: float) -> None:
        center_x = self.width // 2
        head_center = (center_x, self.height // 2 - 60)
        pygame.draw.circle(self.surface, SKIN, head_center, 40)

        # Helmet: a slightly larger circle with the bottom hidden and a brim
        pygame.draw.circle(self.surface, HELMET, head_center, 44)
        pygame.draw.rect(
            self.surface,
            SKIN,
            (head_center[0] - 44, head_center[1], 88, 44),
        )
        pygame.draw.rect(
            self.surface,
            HELMET,
            (head_center[0] - 44, head_center[1], 88, 10),
        )

        # Eyes
        pygame.draw.circle(self.surface, BLACK, (head_center[0] - 15, head_center[1] - 10), 5)
        pygame.draw.circle(self.surface, BLACK, (head_center[0] + 15, head_center[1] - 10), 5)

        # Eyebrows according to expression
        if self.expression == "happy":
            pygame.draw.line(
                self.surface,
                BLACK,
                (head_center[0] - 20, head_center[1] - 25),
                (head_center[0] - 10, head_center[1] - 30),
                2,
            )
            pygame.draw.line(
                self.surface,
                BLACK,
                (head_center[0] + 20, head_center[1] - 25),
                (head_center[0] + 10, head_center[1] - 30),
                2,
            )
        elif self.expression == "surprised":
            pygame.draw.line(
                self.surface,
                BLACK,
                (head_center[0] - 20, head_center[1] - 30),
                (head_center[0] - 5, head_center[1] - 30),
                2,
            )
            pygame.draw.line(
                self.surface,
                BLACK,
                (head_center[0] + 20, head_center[1] - 30),
                (head_center[0] + 5, head_center[1] - 30),
                2,
            )
        else:  # serious
            pygame.draw.line(
                self.surface,
                BLACK,
                (head_center[0] - 20, head_center[1] - 25),
                (head_center[0] - 5, head_center[1] - 25),
                2,
            )
            pygame.draw.line(
                self.surface,
                BLACK,
                (head_center[0] + 20, head_center[1] - 25),
                (head_center[0] + 5, head_center[1] - 25),
                2,
            )

        # Mouth / lips
        if self.expression == "surprised":
            radius = max(5, int(mouth_open * 30))
            pygame.draw.circle(self.surface, BLACK, (head_center[0], head_center[1] + 15), radius, 2)
        else:
            mouth_width = 30
            open_height = max(2, int(mouth_open * 20))
            mouth_rect = pygame.Rect(
                head_center[0] - mouth_width // 2,
                head_center[1] + 10,
                mouth_width,
                open_height,
            )
            pygame.draw.rect(self.surface, (200, 0, 0), mouth_rect)
            if self.expression == "happy":
                pygame.draw.arc(
                    self.surface,
                    BLACK,
                    (head_center[0] - 20, head_center[1] + 5, 40, 30),
                    math.pi,
                    2 * math.pi,
                    2,
                )
            else:  # serious
                pygame.draw.line(
                    self.surface,
                    BLACK,
                    (head_center[0] - 20, head_center[1] + 20),
                    (head_center[0] + 20, head_center[1] + 20),
                    2,
                )

    def draw(self, t: float, mouth_open: float) -> np.ndarray:
        """Return the avatar as an RGB ``numpy`` array for time ``t``."""

        self.surface.fill(self.bg_color)
        self._draw_body()
        self._draw_arms(t)
        self._draw_head(mouth_open)
        # ``moviepy`` expects ``(H, W, 3)`` arrays with the origin at the top left.
        frame = pygame.surfarray.array3d(self.surface)
        return frame.swapaxes(0, 1)


# ----------------------------------------------------------------------
# Video creation utilities

def build_video(
    avatar: MechanicAvatar,
    duration: float,
    make_mouth: Callable[[float], float],
    audio_clip: AudioFileClip | None,
    fps: int,
    output: str,
) -> None:
    """Compose the animation and write it to ``output``."""

    def make_frame(t: float) -> np.ndarray:
        mouth = make_mouth(t)
        return avatar.draw(t, mouth)

    video = VideoClip(make_frame, duration=duration)
    if audio_clip is not None:
        video = video.set_audio(audio_clip)
    video.write_videofile(output, fps=fps)


# ----------------------------------------------------------------------
# Command line interface

def main() -> None:
    parser = argparse.ArgumentParser(description="Generate mechanic avatar animation")
    parser.add_argument("--audio", help="Path to audio file for lip-sync")
    parser.add_argument(
        "--expression",
        choices=["happy", "serious", "surprised"],
        default="happy",
        help="Facial expression",
    )
    parser.add_argument(
        "--arm",
        choices=["down", "point", "wave"],
        default="down",
        help="Right arm gesture",
    )
    parser.add_argument(
        "--clothing",
        default="#0066CC",
        help="Hex colour for the overalls",
    )
    parser.add_argument(
        "--bg",
        default="#FFFFFF",
        help="Hex colour for the background",
    )
    parser.add_argument(
        "--output", default="avatar.mp4", help="Output video file"
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=5.0,
        help="Video duration when no audio is supplied",
    )
    parser.add_argument("--fps", type=int, default=24, help="Frames per second")

    args = parser.parse_args()

    clothing_color = hex_to_rgb(args.clothing)
    bg_color = hex_to_rgb(args.bg)

    avatar = MechanicAvatar(
        clothing_color=clothing_color,
        bg_color=bg_color,
        expression=args.expression,
        arm_pose=args.arm,
    )

    audio_clip = AudioFileClip(args.audio) if args.audio else None
    if audio_clip is not None:
        duration = audio_clip.duration

        def mouth_func(t: float) -> float:
            sample = audio_clip.get_frame(t)
            return float(np.mean(np.abs(sample)))
    else:
        duration = args.duration

        def mouth_func(t: float) -> float:
            # Use a simple sine wave when no audio is supplied
            return 0.5 * (1 + math.sin(2 * math.pi * 2 * t))

    build_video(avatar, duration, mouth_func, audio_clip, args.fps, args.output)
    pygame.quit()


if __name__ == "__main__":
    main()
