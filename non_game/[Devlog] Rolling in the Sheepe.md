# Devlog: Rolling in the sheepe

Welcome to my **devlog** for the game "Sheepe", otherwise known as "Rolling in the Sheepe".

The idea was simple: everyone is a sheep in a **random shape**, you can only **roll yourself**, and the first to reach the finish wins.

It's another one in my series of **One Week Games**, hence the extremely simple idea and limited scope.

(Spoiler Alert: I screwed up again and made the game way too big and complicated. It's at minimum a **Four Week Game**. But at least I *finish* everything I start now and I learned a lot along the way.)

Because this project got quite out of hand and wildly changed course multiple times, I'm afraid the devlog doesn't have nice images or code examples to go along with it. Sorry.

The algorithm to "slice any shape realistically" really needs more clarity, so I'll probably write an article soon that explains *just that algorithm* in more detail (and pictures). This devlog is literally just a *diary* of the development, text only.

So let's get started!

## Task 1: Random shapes

I use **Godot Engine**, which makes this *very* easy.

-   I place points in a circle

-   Then I randomly move them inward/outward a bit

-   Then I tell it to draw this list of points as a polygon.

That's it. Done.

(I'll talk about some issues with this and modifications later, but for now this is fine.)

## Task 2: Turn shape into body

Again, Godot to the rescue:

-   Create a "CollisionPolygon2D" node

-   Hand the list of points we just created as its polygon.

-   Make it a child of a "RigidBody2D" node.

Done.

## Task 3: Rolling Shapes

As we'll be using physics, we don't care about "rotating" the shape perse, we care about *adding angular forces* that cause it to rotate.

Hopefully, the default friction with walls/floors will allow it to move forward and actually make this game possible.

-   When the right key is down, add a POSITIVE angular force to the body

-   When the left key is down, add a NEGATIVE angular force to the body

Going strong!

## Task 4: Splitting shapes

Now, this is where it gets interesting.

One of the "main features" of this game should be **shape splitting.** When you roll into a spike, it should actually **slice your** **body in two.**

### First try: easy and convex

I drew some quick diagrams in my notebook until I saw a pattern. This pattern was really easy to implement and created perfect slices ... *for convex shapes*.

What's a convex shape? It's a shape without holes in it. A circle is convex. A rectangle as well.

(Mathematically precise: you can take *any two points inside the shape*, and the *line between those points will be fully inside the shape as well*.)

Even though players might only *start* as a simple convex shape, over the course of the game this *might not be the case anymore*. So I needed something that worked for *concave shapes* as well. (Which are simply all shapes that are not convex.)

But first, let's take a look at my initial algorithm:

-   Loop through the edges of the shape

-   Intersect each edge with the "slicing line"

    -   No intersection? Continue

    -   Intersection? Save the current *index* (in the shape array) and the exact *point* at which they intersected (just coordinates).

    -   We've found two intersections? Great, we're done.

-   Now *extract* everything between the first and second *index* and save it as a new shape: shape2.

-   Whatever is left of the original array is shape1.

-   Destroy the old body, create new bodies for the new shapes.

As I said, this works flawlessly. As long as you don't forget to:

-   Transform the shape to *global* coordinates before you start. (Taking into account the rotation and position of its body.)

-   Transforming the shape back to *local* coordinates when done. (Calculate the average position of the points, also called the *centroid*, and reposition around that.)

It executes extremely quickly, doesn't take that much code, and works for all *convex shapes*. (And if you slice a convex shape ... it will stay convex, so no issues there.)

### Second try: breaking it down

But when I tried it with a concave shape, my shapes somehow *tripled?* I was astounded at first, as I was certain the algorithm only ran once, so it could only create two bodies (at most).

But then I turned on the "debug physics shapes" option. And I saw what Godot was doing: it automatically **triangulates** concave shapes.

In other words, if I give it a concave shape, it breaks it down into separate **triangles**. Then it saves each triangle as a unique shape of the body, so I can access them separately in the code.

(Why? Because triangles are *convex* and easy to work with. I'm not surprised this happens, I'm surprised Godot does it without telling you and then *lets me access it*.)

So this is great! It's just what we need actually!

We can make this work if we:

-   Create a list of shapes that contains *each triangle individually*.

-   Create a new empty list.

-   Run the slicing algorithm for each shape in that list

    -   Any new shapes created, are added to the new list

    -   If untouched, the original shape is simply copied to the new list.

-   Then we loop through the new list and *stitch together* any triangles that should be together.

The first three parts are easy. (Just modify the algorithm we already have.)

The last part is not. How on earth do I *merge triangles*? And how do I only *merge the correct ones, not those that were just sliced?*

### Merging triangles

Let's think about this.

-   Insight #1: They are *triangles*. Two triangles will share at most two points. If they share only a single point, I consider them "separate" and they shouldn't be merged.

```{=html}
<!-- -->
```
-   Insight #2: The points are *ordered* (clockwise in my case). If we find one point that matches, we only need to check the next point to see if we have a matching edge.

So, for each triangle we loop through its points, and check if any other triangle has a point in it *at the same coordinates*. That is a "matching point". Then we check if the point after that *also* matches with that triangle. If so, we have a "matching edge".

If we've found a matching edge, we add the *non-matching* point from triangle2 to triangle1 in between the matching ones. Then we delete triangle2; it's been successfully merged with triangle1.

Reconsider triangle1 until it doesn't match anything. Repeat until all shapes have been considered

### Ignoring the right ones

Well, what do we know about the triangles that should *not* merge?

They have matching points which *lie along the slicing vector*. Those points were just created, in the slicing algorithm.

In other words, if we find a matching point, we first check if it lies on the slicing vector. If so, ignore it and continue.

There's a fairly standard algorithm for checking if a point is on a line segment:

URL: <https://stackoverflow.com/questions/328107/how-can-you-determine-a-point-is-between-two-other-points-on-a-line-segment>

### The issue here

So I wrote this algorithm. And ... I ran into issues.

Do you spot the issue here? It's rather obvious, in hindsight, especially now that we have the code and some drawings.

*After merging two triangles ... we obviously don't have a triangle anymore*. So the first merge might be fine, but then it all goes haywire. I tried some hacks around this, but in the end I just had to admit I learned my lesson and "merging convex polygons" is a *terrible idea* which you shouldn't even try to do.

No, merging isn't the solution here.

Instead, I think I should *keep* the separate shapes that I have. Once I've sliced some of them, it becomes a matter of **reassigning them properly**.

(All shapes that have matching points, should stay together in one object.)

### Third try: complex and concave

And that works!

To summarize, this is the algorithm:

-   Detect which objects are underneath our slicing line

-   For each object ...

    -   Get all its unique shapes

    -   Slice each of them. (If it doesn't hit the line, it just returns the original shape. Otherwise it returns the two new shapes.)

    -   Once we have the list of *new* shapes, put those that share matching points in the same "layer"

    -   For each unique layer, create a new object, and assign all the new shapes.

The slicing algorithm is identical to before. (Because, remember, the unique shapes that make the object *are* guaranteed to be convex.)

The only new (and perhaps difficult) part is "assigning shapes that should be together to the same layer"

For this, I used the following algorithm:

-   Initialize the list of layers (for each shape) to -1 (or null, or whatever)

-   For each shape

    -   No layer yet? Create a new one and put the shape in there

    -   Check all other shapes.

    -   Do we have a matching point?

        -   Copy our layer to the other shape.

        -   Or, if the other shape already had a *layer* and its lower than ours, take over *their* layer.

        -   Now start the loop from the beginning, because our layer has changed.

    -   When checking matching points, *ignore any points that lie along the slicing vector*.

### About floating point precision

That last part is actually where I got stuck for a bit. The algorithm would work ... erratically. Sometimes it was perfect, sometimes it didn't do anything. I couldn't spot any errors or logical reasons why.

In those cases, you simply try a lot of different simple situations, and check the outcome. Hopefully, this highlights a pattern, or you can isolate the part where it goes wrong.

In this case, that never happened. Even the *simplest* of situations would fail ... sometimes.

But I have experience with those kinds of situations! And a voice in the back of my mind said: *floating point precision error*.

Computers cannot save *all* numbers with infinite precision. There are a limited number of "bytes" reserved for each number, and any precision that needs more bytes is lost.

This means that the exact same *point* (of shape) could actually have a *slightly different coordinate*. Checking "point1 == point2" would *fail*, because they're not *identical*.

Checking whether **a point lies on a line segment** is impossible this way! Because a line is (mathematically) defined as having "zero width", so the point only needs to be *slightly off*, and the check fails.

That's where that variable **epsilon** comes in. It designates a "margin of error" we will allow and which will still be counted as "these coordinates are the same".

The issue? My epsilon was too low. I set it to something like "0.005" (which is quite standard). But upon further inspection, the algorithm works with quite big numbers, so I bumped epsilon up to a way higher value.

That fixed the whole issue. Simply setting **epsilon = 0.1** (or even higher maybe) fixed everything and was the only reason I got stuck for an hour or two.

There you have it. If something behaves erratically, and you're working with *floating point numbers*, it's probably something like this. And never, ever, do a "==" check between two floats :p

## Step 4.5: Nicer slicing

So we have a slicing algorithm, which will *very precisely* cut any shape we give it.

If we're unfortunate, this might cause *very tiny shapes* (which are barely visible). That's ugly and unplayable.

Therefore, we need to check if a shape is *too small* (by calculating its area), and do something about that.

I see two different approaches:

-   If too small, *don't allow the slice*. (Just pretend it didn't go through the object.)

-   If too small, *destroy the second body* (that was sliced off).

I eventually chose the second option, because it simplified the system *and* allowed future gameplay possibilities:

-   Getting sliced is always bad and works in predictable ways, which means clarity and consistency.

-   The *smaller* your shape, the *slower* you move

-   You need a *minimum size* to finish. (Any time you get bitten by the wolf chasing the sheep, you lose something. But during the game, you can also find new pieces and grow yourself again.)

Our last problem becomes: **how do we approximate the area of a polygon?**

There's no need to be precise. Most of these polygons will be *triangles* or something close to it. What to do? We'll just pretend they are a triangle and use the formula for calculating such an area: 0.5 \* width \* height

Then I just played with it, printed the areas of things I sliced off, until I had an idea of what a good "threshold" was.

(In my case, it was higher than I expected. Because we're calculating an *area*, even a tiny 10px by 10px square ... has area 100. I settled on a number around 400-500.)

## Step 5: Following the players

We need a camera that always keeps *all parts* of *all players* in view. Preferably it should:

-   Stay zoomed in, so things don't get too small/far away

-   Also show what's "up ahead"

-   Not be janky or stuttery

From earlier (local multiplayer) games, I've learnt some hard lessons about camera management. Namely, that you **shouldn't try to create a *camera* that keeps all players in view**, but instead should **create a *game* that ensures all players stay together**.

You have to think the other way around. Because no matter how hard you try, if you allow players to get *far away from each other*, you'll never find a camera setting that stays close and zoomed in.

And so I settled on the solution of **locked-in sections.**

-   The map consists of multiple "sections" placed after each other.

-   Each section *ends* with some sort of lock. This can be a physical obstacle, a minigame you need to complete, anything that stops you (for a while).

-   This lock ensures that, 99% of the time, the first players are slowed down and the last players can catch up. If that doesn't happen, *any player that's more than 1 section behind is simply teleported forward*.

In my opinion, this is the best solution.

-   Players are never "out of the game". (Either by being eliminated *or* by being so far behind they can't practically win anymore.)

-   Players doing well (which are in front) are not *punished* for it. Instead, they simply need to overcome *extra* challenges to maintain their lead, while allowing other players to catch up a little.

-   Breaking the map into sections creates a nice, visible sense of progress. You're never lost. You're never unsure about why you were teleported forward. The sections give clear indication.

In conclusion:

-   The camera is simply placed on the *average* position of all players, but *slightly* forward (to show what's coming.)

-   By calculating the *maximum* distance between players, I know how far we need to zoom out to keep everyone in view.

-   That's it. The camera itself has no other logic, it's up to the *game* to keep all players nicely together.

## Step 6: Creating the map

At first, I wanted to make a game that only goes to the right. (Which is typical with these kinds of "runner" or "platformer" games.)

This, however, presents several issues:

-   If you have good speed, you'll just *fly* forward and nothing can really stop you. (Because you only need to go right, is there any reason to slow down or roll to the left?)

-   It makes it *much harder* to keep all players in view. (We'd have loads of unused space *vertically*, whilst players are far apart *horizontally*.)

-   After a while, if we go to the right long enough, we run into those same "floating point precision" errors, because our coordinates are just too large.

That's why I decided to make a map that is more like a *maze* and can go in any direction.

This is the idea:

-   Predefine a "world size". (For example: max 100 tiles wide and 100 tiles high.)

-   Start at the top left corner.

-   Create a random route through this world, ensuring that ...

    -   All of it is reachable

    -   It is long enough to warrant a full level

    -   It's broken into these *sections*

-   Place a finish at the end

My first instinct is always to reach for some *perfect* algorithm to generate a *maze* or something. That's just how programmers work :p But I've learnt over the years that trying a naïve/dumb/simple solution first is usually *all you need*.

(Additionally, we don't need or want a *maze* for this game. It is *side view*. Gravity is always pulling us down. We can only roll (with random shapes). Preferably, the route will mostly flow downwards and switch between left\<=>right once in a while.)

All we need is:

-   A route that regularly changes direction

-   And that keeps players together, so we don't need to zoom out a lot

Well then, *let's only fulfill those wishes* and *nothing more.*

There's *no need* to generate a full map beforehand. There's *no need* for the route to make sense. (We can just re-use a location we've already been later on, with a completely new room.)

This is the idea:

-   Check where the first ("leading") player is

    -   When they move into a new room, we immediately instantiate a *new room* at the very end. (This way, we build the map as we go, ensuring players can always move forward.)

-   Also check where the last ("trailing") player is

    -   When they move out of a room, there's no use for it anymore, so remove it.

-   When picking a new direction for the next room ...

    -   The longer we've been going straight, the higher the probability of changing direction

    -   Prefer a direction that keeps all players in view.

    -   After placing new rooms X times, we *end* the current section (with such a "locking mechanism").

**Remark:** and when we simply cannot place a new room? We stop there. We place a *teleport* or something. It waits until everyone has arrived, and then we simply *zoom* to a new level/part completely.

### Does this work?

Yes. It works great!

It's not that hard to program, whilst allowing the game to basically be as varied (and *endless*) as possible.

(Additionally, it's great for performance, as there will only be \~10 chunks in the game at a given time. But that really won't matter much, unless I decide to port this game to mobile.)

There's only **one issue left: how do we select/place rooms?** How do we ensure a room fits onto the previous one, and there's always a path forward?

I've done this in the past with this approach:

-   Each room has several openings

-   I save these locations in the room. (For example: openings left = index 2 and 4.)

-   When selecting a new room, we simply pick one that *has the right opening*.

This works well. But those previous projects were different from this one, given that:

-   There was no need to create a single route. As such, rooms often had *multiple openings* going in multiple directions.

-   Rooms had to keep their orientation. (I couldn't *rotate* them, for example, to match them.)

So, we need to modify the approach for this game:

-   When matching edges, we **are** allowed to rotate the room. (There's no reason not to.)

-   Any edge we **do not** connect, is closed.

    -   When a new room is placed ...

    -   We check all openings in the *previous* room, ignoring the ones we actually used.

    -   For each one left, we place a solid block on that location to "fill" the gap.

### What are "rooms", actually?

I notice I've been saying "room" all the time, without giving a clear example what that entails. That's partly because *I* wasn't sure yet.

Now I can explain this a bit better.

Each "room" is a block of grid tiles (probably 4x4) that has **one unique challenge or mechanic**.

-   The most basic room is just empty.

-   But an "obstacle room" might be filled with all sorts of bodies you'd need to navigate through.

-   And when you're in the "glue room", you're able to glue yourself back together (if two of your pieces touch each other).

By chaining these rooms together, you are constantly presented with new challenges to overcome, as you progress towards the finish.

Additionally, it gives me great *control* over what appears and how often. (You wouldn't want a game that, by pure chance, consisted of 100% glue rooms and nothing else.)

## Step 7: Trying something completely different

So I implemented everything I talked about in the previous section. And I tested it. And I played it.

And it ... just didn't work. These are the reasons (I think):

-   Gravity is always down. As such, most of the game you're just *falling down through a bunch of rooms*.

-   It created quite a static layout that wasn't very pleasing.

-   There's no way to go upward, or jump, or anything. You can only *roll left and right*.

It's much better if

-   Players have some *solid (horizontal) ground*

-   Moving down/up only happens sporadically. (And if it happens, you get support for it. Like a trampoline on parts going up.)

-   Players can *roll onto walls*. (So when you roll into a wall, you *cling* to it, so you can follow it.)

So let's turn it around.

-   The map is one big *chunk of blocks* at the start.

-   Instead of placing new rooms, we just *erase* part of the blocks. (Essentially creating something like a cave or tunnel through the map.)

    -   (Conversely, instead of deleting rooms on the tail end, we just *fill it back up*.)

-   Regularly, we change the width of that eraser. (Sometimes it removes blocks 2 wide, sometimes 1 wide, sometimes 3, etc.) We also randomly add an "offset" so new rooms don't all start at the exact same level.

-   When changing width, we add *slopes* to make it gradual.

-   (The probability of moving vertically is much lower than moving horizontally.)

### Did that work??

Yes! It did! (In hindsight, it's obvious this was the better choice. But hey, lessons learned.)

Now players can actually roll onto stuff. They stay contained within the grid, while having more than enough space to maneuver. The routes are varied and can already be quite challenging. (This is *before* I implemented nice slopes and clinging to walls.)

It's surprisingly *rare* that the generation fails. (It has painted itself into a corner and can't get out.) If it happens at all, it's usually after 30-60 seconds of playing, which is already a good length.

So, how exactly *do* we add slopes between height differences?

-   When erasing a new part, check all cells within that section *+ their border*. (So, increase the room size by 1, then check all cells within that rectangle.)

-   For each cell that has:

    -   Exactly two neighbors, which are *not* opposite each other, add a slope.

    -   (If the neighbors are opposite each other, this is the perfect location to place a door or a laser or something. But that's for a later moment.)

**Remark:** Rotating the slope correctly is a minor implementation detail (which depends on how Godot handles tilemaps and how I happened to draw the slope), so I won't bore you with that. Also because -- and this is me from the future -- I ended up using a different system anyway ("autotiling").

**Remark:** technically, we only need to check the *border* right now, not the inside of the room. However, as I plan to *use* the empty space inside for things, I already set up the loop to check those as well.

**Remark:** we *also* check for existing slopes that have become useless. Because we placed a new room, the environment changed, so older slopes might not be needed anymore.

### In conclusion

Right now, we have randomly generated maps which are fun, playable, and even finishable (with our limited toolset).

It still crashes whenever it can't find a solution, but we'll solve that soon.

For now, I want to add several more (interesting) ways for movement ...

## Step 8: Better movement

Right now, you can *roll left* and *roll right*. Because we've added slopes, this already gets you quite far.

But you still can't go up. And you still get stuck on high vertical jumps/obstacles.

I see *two* interesting things to add:

-   **Clinging to walls =>** whenever you roll against a wall (with enough force/close enough), you stick to it

-   **Jumping** => whenever you **release both buttons simultaneously**, you jump.

Jumping is simple to implement: apply a force *away* from the ground.

Clinging is, interestingly, kind of the opposite. Use a *raycast* to detect whether we hit something next to us and the *normal* of that collision. Then apply a (strong) force *in the direction of that normal*, pushing us into the object.

Because of the default "friction", this causes us to stick against the surface and roll along it.

At first, I created a bit of a "rough" implementation of both features. Jumping was endless (you didn't need to be touching the ground). Clinging only happened horizontally (if a wall was to the left/right of you).

But ... experimenting with this led to some amazing insights! With this system, you could:

-   Cling to a wall and then *stand still*

-   Press *jump* to release yourself again.

Not only was I able to finish *any* route this way (with some trial and error), it just felt *cool*. It felt cool to roll up to something, then stand still in mid-air, waiting for the perfect moment, then launch myself again.

If I can perfect *those* behaviors, this game will certainly be fun to play.

Additionally, there's not much more to do here. We only have two buttons. They each do something separately, they do something combined, *all my inputs are taken.* So, any more variety/mechanics shall have to come from the levels themselves and the elements within them.

## Step 9: Making the first finishable level

What do we need to make a first finished, playable prototype?

-   A finish => reaching it first, with *all* your pieces, wins you the game.

-   A "section lock" system -- breaking the route into pieces, keeping it all manageable and on-screen.

That's it! So let's make that and then *test the game*.

Creating the *section lock* and a *teleporter* (in case you were stuck) were relatively easy. I simply:

-   Place a large room

-   Wall it off with edges, except for the direction you came from.

-   Add a "module" (just a script and some objects) with a certain minigame

-   Once completed, the edges are removed and you can continue

For teleporters, the same is true, but once all players have arrived *the route restarts completely somewhere else* and *players are teleported there.*

However ... the question of "how exactly do you win?" haunted me during that period.

At first, saying something like "reach the finish with *all* your pieces" seems great.

But there are problems. This encourages players to *lose everything* (and destroy themselves), because it's much easier to get through obstacles if you have only *one tiny piece*.

At the same time, if you are split between a few pieces, it might be really hard to bring them all to the finish. One of them might be stuck somewhere, and there might be no way to get it out. And because it's stuck somewhere in the back, the camera needs to zoom *way out*, and the route generation gets stuck (because there's no space).

It's just not great.

I want to change it to the simple objective: "finish to win" Just one piece. Get one piece over the finish (first) and you win.

Of course, this still has the first issue: the best strategy is to always destroy yourself.

How do you solve that?

-   Option 1: *penalize* this behavior

-   Option 2: add *other* strategies that are just as viable (or even better)

Penalizing is annoying. It can easily lead to frustration and a "stale game". So the second option will have to be used 90% of the time.

But it's a party game. I don't want to teach new players "these are the 4 ways to win". No, the objective needs to be that simple one-liner: reach the finish first.

Instead, I will try to (invisibly) **nudge players in the right direction** by being smart about what elements I place.

For example, let's say I want to encourage players to stay big. How do we do that?

-   Idea: Being big makes you faster

-   Idea: Add a "lock" or "gate" you can only pass if you're large. (Otherwise it takes a while, or it's harder.)

-   Idea: you can *slice* other players by bumping into them. The bigger you are, the higher the probability of successfully slicing someone else.

I don't need to *teach* these things or *explain* them specifically. Just place them in the game/in a level. Yet they give players a reason to vary their strategy and try new things.

That's what I'll implement now: you win if you reach the finish first. Any part of you.

**Remark:** of course, I could add powerups later that modify this. A "time penalty", for example. Or a "curse" that requires you to finish all your pieces anyway.

## Step 10: Better Routes

Right now, there's quite a large probability of getting stuck (and having to place a teleporter). Even if I can clearly see some free routes that could be taken.

I want to lower this probability of placing teleporters *as much as possible*. (It's more fun if the route keeps flowing and players aren't stopped artificially.)

To do so, I tried these techniques. If we can't place anything ...

-   *Reduce the room size*. (Because a room of size 1x1 most likely *can* be placed, even when a 3x3 one cannot.)

-   *Backtrack*. Try to attach a new room *earlier* in the route. Continue backtracking until you find something, *or* you've reached the room that holds the current leading player.

-   *Loosen the restrictions*. Normally, I disallow overlapping *and* adjacent rooms. But if we seem stuck, I can start allowing adjacent rooms. And if we're still stuck, I can allow some overlap.

This improves it somewhat. It's not *amazing*, but it's a good start and yields good routes for now.

By loosening the restrictions, and allowing rooms to overlap, I did create an extra problem: it's not *clear* what the route is anymore. What way is forward? Sometimes you don't know.

After some experimentation, I found the best solution was simply to allow this, but *add edges ("outlines") around the rooms* (like I did with the locks) This way, it's still clear what the rooms are and what path you should take.

In a general sense, I learned: using **edges** to separate stuff requires less space than using **full blocks** to do so. So maybe I'll use this tactic way more.

Another thing I learned, just from playing/testing the mechanics so far, is that:

-   Clinging to walls should *not* be automatic. It's too strong for that, which makes some parts ridiculously easy, and others (near) impossible. It should only be activated on certain areas.

-   The less "round" your shape, the less you're able to roll. (Which is obvious, I know, but ...) The difference is *so big* that it's basically impossible to move well if you're not *somewhat like a circle*. I should invent something to "help" the flatter shapes, I think.

## Step 11: Throwing sand against the wall

And now we're at the point where I simply **implement a bunch of stuff I thought of**. Then I check what works best, and what doesn't, and keep the best things.

(For example, I invented \~10 terrain types, a few ideas for powerups, and a few general game rules. I can't *predict* what will be the most fun. Nor do I know the best *order* in which to teach them to players. So I just implement all of it (as quickly as possible) and then *test*.)

The results?

-   Most of my ideas work great! They are a fun challenge, without just being impossible or impossible to understand.

-   Nevertheless, I *do* need to finetune physics parameters. And I *do* need to restrict terrain placement to avoid some bad situations.

    -   (For example, if the room goes *down* it's extremely annoying if it has a *reverse gravity* terrain. Because it constantly pushes you up, it's near impossible to get through this room.)

-   By implementing these things, I've generated tons of new ideas. I also learnt that I should probably simplify the game. (Now there are: terrains, powerups, locking rooms, and obstacles/items. Perhaps the last three should all just be shoved under "special room".)

-   **And the route generation ... needs a serious rewrite.**

In this period, I also implemented many other features I would need anyway:

-   The camera cannot show anything out of bounds. (So no ugly spaces outside of the grid if we're zoomed out.)

-   There are "light circles" around players, the rest is dark.

-   I implemented "autotiling" with prettier tiles. It means that my game engine automatically chooses the correct sprite based on surrounding sprites, so it all connects well and looks good (and organic).

-   I implement "catch up mechanics". If you're too far behind, you are teleported forward. If you're not moving for 10+ seconds, same thing. All of this, obviously, has a cost in the form of a *time penalty*.

## Step 12: Better routes, For real now

The current route generation algorithm is "fine". But now that the game has evolved, this isn't enough anymore, and I have requirements it cannot meet.

(Additionally, the *actual route* is *the backbone of this game*. It's the most important thing. It's what makes or breaks the game. I think it's more valuable to spend extra time here, than try to cover it up later with all sorts of powerups or other mechanics.)

To remind ourselves, here's how the current algorithm works (in simplified form):

-   Get the last room we placed.

-   Try to place rooms of random size in random directions *next to this room*

-   Once we find something, place it.

-   If we haven't found something after loads of tries, it's clearly impossible, so place a teleporter and stop there.

This has the following problems:

-   Trying this algorithm *thousands of times* is very resource intensive and introduces lag/stutter.

-   Additionally, there's no *guarantee* that it finds something sensible. If we're out of luck, it only tries stupid configurations that would never work, and misses the obvious one.

-   It's terrible at using the space it has. (Often it has *loads* of space on the right ... and only places a 1x1 room before going left.)

-   It's hard to control this with extra requirements, such as "no more than 2 rooms vertically after each other".

This got me thinking. I've implemented a "grow rectangle" function, which is *fast* and already *used a lot*.

**Insight #1:** why don't we start each room at size 1x1, and then simply *grow* it until it hits something? (Or reaches a maximum size of 6x6; we don't want humongous rooms spanning the entire world.)

This would guarantee we use *as much space as possible*. Additionally, we don't need to retry the same location at different sizes, as this *will already have happened*.

Which got me thinking again. When you look at a rectangle ... there are only a limited number of spots to place an adjacent rectangle, aren't there? Currently, we're running this loop *hundreds* of times ... but there aren't even that many options. Not even close.

Let's calculate an example. Our current room is a 2x2 rectangle. We are trying to place a 3x2 rectangle next to it. (Which are "medium size".) Then we only have ... 14 possibilities.

IMAGE: devlog-allpossibleplacements

**Insight #2:** just generate a list of *all* possibilities at the start, filter those we do not want, and pick the best option.

It should be much faster, we shouldn't miss (good) options, and it's easier to manipulate with extra requirements. (Even on two huge rectangles, the number of possibilities is below 50.)

And that's what I did.

**Remark:** I also took the time to clean up the *map* and *room* scripts. Both were just one giant script with 1000 lines of code at this point, doing *everything*. Now each of them has about 8 "modules" that do just *one* thing in \~50 lines of code.

**Remark:** interestingly, when I started this project, I didn't know I would be using this concept of "placing rectangles", and thought the route would just be a series of 2D points. Hence, the *main variable in the game* ("path") was saving *coordinates*, not the *rooms themselves*. Over time, this led to hundreds of lines of code like:

"var my_room = get_room_at(get_location_at(get_my_index()))"

Which is just horrible. Saving the *rooms* in that list instead, saved me tons of code. Yet I would never have made that "obvious" optimization if I didn't completely rewrite and restructure this script.

**The results?** Again, works wonderfully, and it's stupid (in hindsight) that I didn't try this first. Using these tweaks, I was able to increase the *quality* and *performance* of the maps in the game:

-   **Controlled variation** => Take an average over the last 5 rooms. The bigger those were, the smaller we must be. (This means the route alternates between tighter sections and huge open spaces.)

-   **Preferred movement** => check directions in this order: continue horizontally, go in opposite horizontal direction, go down, go up. Usually, the first direction yields a result fast.

-   **Stay away from edges** => if close to the edge, simply *do not consider that direction at all*. (Saves a lot of performance.)

-   **Sneak peek** => The game would lag/stutter when there was *loads of open space in front of us*. Because it would try every rectangle and then grow all of them until maximum size, before making a decision. As such, before starting the algorithm, I try *one* room at maximum size (with some random size/displacement). If that fits, great, just use that.

    -   This is a way bigger improvement than you'd think. In about 75% of the cases, it saves us all the computations of the algorithm (hundreds of rectangles to create and check), while placing the ideal room.

    -   And because I control the "maximum size", it works for big rooms and small rooms alike.

IMAGE: debug_sheepe_5

I disabled some things for the image here, such as the lighting effect. I feel like it shouldn't be so dramatic. Or only used during "night time" sections, or something like that.

Another thing I disabled was my algorithm for adding slopes in 90 degree corners, because it stopped working after this update. Speaking of that ...

## Step 13: Better slopes + "inner tiles"

Now that we have **big rooms** (consistently, in a controlled way) I can **fill the rooms** with things!

The easiest first step is to fill them with *more tiles*. (Which might split the room into two, or add a few islands, or something like that.) However, we don't want these to block entry to the room.

As such, we need a function that:

-   Given a position in a room

-   Checks whether any of the *neighbor* tiles are part of a *different room*.

-   If so, disallow that position.

Once we have this, we can **also** use it for adding back slopes! (Because, again, in a "rolling game" we want as many smooth transitions as possible.)

This works great, as you can see here:

IMAGE: debug_sheepe_6, debug_sheepe_7

Because anything *outside* the room is *also* "a different room than us", none of the tiles are placed against the edge, ensuring we have a path through the room.

Of course, for variety's sake, I *could* allow this as well. But this has to remain a "One Week Game" and I'm stopping here.

## Some tricks

I *did* end up having to implement an extra trick.

Because of the "autotiling" system (and adding slopes), it happened quite often that you could enter a cell (with a slope) ... that didn't belong to any room.

It was ugly, it was messy, yet I really wanted to keep the smooth slopes.

So, from now on, each room *is actually one size bigger than it appears*. This allows me to paint the terrain correctly *and* always know which room a player is in. But when it comes to (visually) placing the room, I use the *shrunk version*, which is just one size smaller. So everything looks the same as before, just much cleaner (and bugfree) under the hood.

Another trick had to do with *performance*. Right now, I checked whether I needed to add a new room *every frame*, and checked whether I had to delete a room in the same function.

Of course ... if players were speedy, this meant *every frame, loads of rooms were being added and deleted*. Which caused huge stuttering.

To solve it, I simply put it on a timer. It only checks if it should update once every second. And it checks it *separately* for removing and adding rooms ( = two separate timers that never fire in the same frame).

(Because removing a room is just as heavy (performance-wise) as adding one. It needs to remove all the terrain tiles, fill the space with solid tiles, update all entries in the map, remove itself from the path, and overwrite *many* pixels in the terrain mask.)

## Step 14: Running with the wolves

When I started this game idea, I thought of it as an "endless runner".

You were sheep. A *wolf* would be chasing you, always from the left. And if it caught up with you, you died.

Now that the maps are *more varied*, it's impossible for me to write a "computer player" (aka the wolf) that follows the players around. Additionally, such a wolf would only *punish* players who are already behind.

Instead, I invented the following idea: **the last player *becomes* the wolf.**

When you're in last place, you turn into the wolf. You become faster, can skip certain challenges, but most importantly: **hitting another player takes a bite out of them.** (Which, most likely, causes them to fall behind and become the wolf.)

It will be a constant driving force, pushing you forward and making you take risks. But it's not controlled by the computer or manually programmed by me. It's a player, which is way better.

**Remark:** in *single player* mode, you obviously can't have this. I think single player mode will either be *survive as long as possible* or *finish in the shortest time possible*. But I need to think about that some more.

Here's what the wolf looks like:

IMAGE: debug_sheepe_8

Of course, it had to be toned down a little. After biting, it takes a second before it can bite again. (In general, if a "bite" would result in a player losing all their bodies *or* becoming too small, it doesn't go through.)

And the wolf has to be *way* more visible than it currently is. I just drew a very quick sprite to test it.

**Remark:** when testing this behaviour, I was constantly disappointed about how ... ugly it looked? Just boring and ... weird. Then I realized: slicing a body is quite an operation. It shouldn't be this surgical precision slice, it should be more like an *explosion*. So I added a *force* that pushes the new blocks away from each other (after slicing). This solved *so many issues* and made it look much better in general.

## Step 15: The Rolling Factor

All this time, I've been thinking: "the game is called *rolling in the sheepe*, it's about rolling ... yet I spend an awful lot of time in the air"

Why? Because non-circular shapes are just really hard to roll. (And most powerups/rooms, for now, require jumping to solve.)

And then it hit me. A new rule for the game that would be amazing, if it worked.

**Rule: the *more you roll*, the *more round your shape becomes*.** (Conversely, the more time you spend in the air, the more it deforms.)

It took quite a while to implement this properly, as I'd never done anything like it before. But this is how it works:

General module:

-   Each frame, I track if you're in the air or not. (Which simply means: are you touching terrain or not.)

-   After a few seconds, I take an average from that.

-   If you've been in the air 50% of the time (or more), you deform

-   Otherwise, you become more round

To become more round:

-   Check the total number of points in the shape. If it's below 5, you're a rectangle and can't be round. So, I "enrich" the shape by adding a new point halfway each existing edge.

-   Loop through the points and make them global. (By default, these are local to their own center.)

-   Approximate the radius of the body. (Simply get the approximate area. For a circle, A = pi r\^2, so r \~= sqrt(A/pi).)

-   Calculate their *angle* and *distance* to the center of the body.

-   Move the point to stay at the same angle, but with its distance closer to the *radius* of the body. (In other words, each point moves closer to the position *it would be* if the body were a perfect circle.)

Do this a few times (for about 30 seconds), and your body has become a (near) circle.

After a while, I noticed this has issues if points are really close to each other (on the original shape). This would prevent the shape from rounding well, as they all moved to the same new location. Solution? I *snap* the angle to the 8 predefined directions (horizontal, vertical and diagonals), ensuring that most of the points will space out around the circle.

IMAGE: explanation_rounding_shapes (to do, make it)

For deforming shapes, I did the opposite: move points to a rectangle. (In this case, I already have the *bounding box* of each shape, so I can just move points towards that.)

This is *fine*, but a rectangle is also quite a smooth shape. Which means it doesn't really "deform" you, it merely "gives you sharper corners". I'll have to see what I do with that.

**Remark:** I switched my area approximation code to the **Shoelace algorithm (by Gauss)**. It's just as fast, but *way* more accurate. Didn't know it existed before now :p

I want to do even more with rolling, like buttons you can only activate by rolling over them. (And I have to become worried about performance at this point ... manipulating dozens of physics shapes constantly.)

## Step 16: Rolling with the punches

By now, I've made these comments several times:

-   I should do more with the fact that you're rolling.

-   The game should be simplified so much that anyone can play. If I have to, the first level should just be *pressing one button* (to roll right).

-   I have way too many different mechanics outlined (terrains, obstacles, special rooms, powerups floating in said rooms, things that can protrude from the terrain ...) These should be streamlined and simplified.

Just now, finishing all the previous tasks, I had an insight.

I've done all this work to ensure a route that flows smoothly, where you can always reach everything, with enough space between rooms to fill it with solid tiles.

This means that there is **one place where I can always put something special: inside tiles.**

Coincidentally, rolling is also something you do **on a tile.**

Which led me to the following "rule" for this game: **all special elements are simply an extension of an existing tile.**

-   Want to place spikes? Find an existing tile and place the "spikes" object on top of it.

-   Want a button? Find an existing tile and place a "button" object on top of it.

This means *no* powerups (or other obstacles) just floating in mid-air. Which is great, as it gives us back some clarity and space. (Especially when players are sliced up, in smaller rooms, it becomes *quite full*.)

This means *no* special cases for certain elements, like a laser that spans the full width of the column. (Instead, I can repurpose that to the new system: I can stick a laser gun into the wall, protruding just slightly. Once in a while, it *shoots* that laser across the room. Same functionality, but the underlying code and mechanics stay consistent everywhere.)

So, how do we create a system like that?

-   Pick some "special thing" we want to place

-   Get a list of all tiles within our room.

-   Pick a random one. Look at its neighbors to find an open side.

-   Check if it's a slope. (If so, our sprite just needs to rotate to match the angle.)

-   Place the thing at the desired location and rotation

-   (Remember it was placed there, so we remove it properly when the room is removed.)

Here's what that looks like. (Ignore my extremely crappy art for the spikes, I needed something to test.)

IMAGE: debug_sheepe_10

That was quite easy. Should work well.

### Realistic slicing is too realistic

The title of this section, therefore, refers to something else. No matter what I tried, I noticed a few core elements of the game just *weren't fun*. I'm happy I figured out how to do it, and maybe I'll use the technique in some other game.

But the whole **slicing** thing isn't great. You see, I did a quick test. I wrote a few lines so that "slicing" a shape simply yielded two smaller circles. (Like a snowball exploding into two snowballs.) And guess what? It was *so much more fun* and *intuitive*.

It looked better because there weren't all these weird shapes floating around. It played better because you weren't just stuck after being sliced.

So ... well, I guess my whole algorithm for accurately slicing stuff will just be an optional feature. For the people who want the extra challenge.

(Feels like something I could use in a puzzle game, at a later date. Or a party fighting game where you *literally* slice your opponents.)

### Realistic physics are too realistic

Similarly, I noticed an issue with "realistic rolling physics":

-   Some heights are too great to roll over. You need to jump.

-   But when you jump, you're likely to hit the ceiling with your head ... which causes you to reverse direction.

-   (Rotating "left" means rolling "right" if your hitting the ceiling. You can think of it as the ground being reversed in this situation, and the friction on the ground is the only thing making rolling movement possible.)

This was just annoying. It happened too quick to "adapt" to it or use it for anything. I almost considered throwing out this whole rolling thing as well ... but decided that was my panic talking.

Instead, I added these features:

-   If you **hold both buttons**, you "**air break**". This means your vertical velocity is 0 (you won't move up/down), while your horizontal velocity continues. (It's even made more powerful.) This allows you to stop your jump/fall whenever you want, allowing much more precise movement in difficult parts.

-   (Quick-tapping both buttons still makes you **jump**.)

-   **Clinging** is enabled by default ***on ceilings***. (Again, jumping will disable clinging for a few milliseconds and you will shoot away from the grip of the ceiling.)

## Step 17: Throwing more sand against the wall

Now was, yet again, the time to implement all different "special elements" I came up with. See what works, see what doesn't. Let's hope we have a fun game by the end.

As a reminder, these are the elements to do:

-   Different "locks" => these are the minigames you have to play once in a while to open a gate. To slow down the leading player and bring the group closer together.

-   Special elements => all sorts of things (that might be good or bad) which you will activate/collect by touching their tile.

Once these are implemented (they work, they are fun, etc.), we're close to finishing the game. Then it would just be:

-   Create tutorials for everything (that needs one) + create "campaign" structure with levels

-   Loads of polishing, balancing and playtesting. (Includes adding the soundtrack + sound effects, some particles, etc.)

-   Done!

I'll probably go over my "One Week" limit again. But this time there's a good reason: my first ideas were hard to implement, yielded some annoying bugs, and then ... had to be thrown out because it just wasn't that fun.

## Step 18: Welcome back after a long break!

Guess what? When I said I could use the slicing mechanic "for a party game where you realistically slice your friends" ... that's exactly what I did!

I worked on that game for a few weeks, released it for free, then worked a few extra weeks, and released the final paid version. Then there were two interesting game jams, so I participated (which took another month).

And then I looked at my list of "unfinished projects" and realized I *really* needed to cut down the length of that list. So I powered through and finished a bunch of older projects, until we arrived at this project again.

Looking at it with fresh eyes, with some months of distance and extra experience, I realized a few things:

**Realization #1:** I made it too big and too complex -- again. I discarded many of the original plans and decided to stick with what I already had, keeping the game smaller in scope.

**Realization #2:** Nobody is going to go through a whole *campaign* for a game like this. It's supposed to be a lighthearted, quick, fun game. So I'm not even adding it. Instead, in the menu, you have two options: *tutorial* and *play*.

The tutorial is a special map that teaches you the actual inputs, objective and core rules of the game.

The play map is just the standard game where *anything* can show up. (At the start, it selects a random subsection of the full list of rooms/terrains/etc.) And here's the kicker: **the first time it's added into the level, a tutorial is always placed before it**.

For example, let's say I want to add the "spiderman" terrain for the first time. Then I place a big empty room with the tutorial image for it as the background. After that, I place another room with that terrain actually inside.

This way, nothing has to be taught upfront, or from a list in the main menu. The tutorial appears *right* before the first time you use it. I don't even have to make those menus!

(The downsides are, of course, that you can't *pick* which things you want or don't want. And the tutorials will keep showing up, even if you already know how something works from earlier plays. I could make an option to turn off *the whole system*, but that's it. But hey, I just want to try this, as it seems like a good idea to experiment with.)

**Realization #3:** Interactive menus are awesome. So I'll just build a simple map with two huge rooms (*tutorial* and *play*). When you login, you get a sheep to control and roll around. Once everyone is inside one of the rooms, you've chosen that option and the game starts.

**Realization #4:** Nobody is waiting on a *huge* game about rolling sheep with *loads of content*. I need to stop trying to make every simple idea "my next big thing that is going to shock the world". Just add a few rooms, a few terrains, polish the core gameplay, and call it **done.** Then I can cross it off the list, continue with a new project, with my improved sense of scope :p

So that's the plan now:

-   Clean up some code and assets. (Had to do that anyway, now it's also a way to get familiar with the code again.)

-   Finish the core mechanics and create that tutorial map/system to explain them. (If too difficult, find ways to simplify.)

-   Write a system to always show a tutorial before the first time you use something.

-   Create the interactive main menu

-   Then see if I want to add more rooms, or perhaps even remove some, or what I want with the content in general.

To be honest, this is going to be a pain. I'll need to work really hard for a few days, on boring and confusing things, with almost no motivation to speak of. But I know how important it is to *finish stuff* and the rewards you get from it. And, of course, the reason I started this project is because there were certain things that I found interesting and fun, so I'll focus on those.

## Step 19: A few days later

Yes, it was a pain. These few days weren't very productive and I watched more YouTube videos to procrastinate than I care to admit :p

But, as long as you keep doing *something* every day, you get through it.

Right now, those "dynamic tutorials" are working nicely. I also fixed a handful of other bugs and *greatly* cleaned up the code. (It's baffling how I thought my previous system for doing things was fine.)

Also, I realized that "teleporters" will never have a tutorial. Why? A teleporter is only placed when the algorithm runs out of space to place new stuff, so it panics and converts the last room into a teleporter. It's not easy to "predict" that in advance.

So they, as the exception, get a tutorial *on themselves* (instead of before they are placed) the first time a teleporter room appears.

### Last rooms

I already had some neat ideas leftover for rooms/locks, so I implemented those.

Some were easy. Take the "fast gate": it just opens/closes quickly, so you need to wait a bit and then time your jump through.

Some were a whole minigame on their own :p Take the "painter": to unlock that room, you need to paint the background 100%. How? Well, by flying through the room, as it automatically paints wherever you go.

This meant I had to do some magic with *textures* and *masks* to make a rectangle of the world paintable. And then more magic to get a method for checking "is it roughly 100% filled?" without killing performance.

(I created a 2D array in the background, with a *very* low resolution. Like a downscaled version of the real texture. When a player paints, it just checks which cell it corresponds to, and then sets that cell to "painted". Once all cells in the 2D array are true, it deems the room painted and unlocks.)

### Last items

The items/obstacles were a mess. Before taking a break, I *did* have the luminous idea of not actually including loose items. Instead, obstacles are simple "special blocks" of the terrain, instead of regular blocks.

But this also meant that all my old notes/ideas for items were now worthless and I had to come up with new ideas.

After some brainstorming, I realized there were a few obvious options. (*Spikes* that slice you, *trampoline* that shoots you upward.) And that most other options were just identical to the terrains I already implemented. (A block that slows you down when rolling over it, one that is slippery like ice, etcetera.)

There *are* options that are really cool and unique, but I wasn't sure if I had the time and motivation to add them, so I left them for now.

### Last rule polishing

There were two big unanswered questions left:

-   There are quite some rooms and terrains that do stuff with *coins*. But what if they never show up? Is there a way to make coins actually integral to the game, part of its core ruleset?

-   What to do with the body splitting? What's the point of all those extra bodies flailing about at the back?

After some thinking, I decided on the following.

Question 1:

-   If you have coins, the wolf does not *split* you, but rather takes a coin from you. (Both makes the wolf more interesting to play actively, and gives anyone a use for coins.)

-   Ensure at least one *terrain* or *lock* is included that does something with coins.

Question 2:

-   Any body of yours *that does not finish* results in a time penalty. (The game ends once every player has *one* body over the finish line.)

-   Older bodies of yours can still activate stuff, so they can still be useful (or very annoying) if you keep track of this. (For this to work, we need one other rule: *when one of your bodies does something or gets something, this is copied to ALL your bodies*.)

-   Add many ways to get back together again

-   Ensure at least one *terrain/lock/item* helps you retrieve or use your old bodies.

As always, it's about compromises. I want the randomly generated routes to be *as varied as possible*, but I need some restrictions and certainties to make the game work in general.

Not all of this will be explained in the tutorial mode. It would be way too much *and* players really don't need to know it at that moment.

### General polishing

For a light-hearted game like this, visual and audio polishing is really a must. (It's a chaotic game about rolling through an environment. You want the rolling to *feel amazing* and the environment to be *really fun*.)

However, I've been working on the game too long and really don't have the motivation or time left, so I'm afraid it's going to be way more basic than that.

This is what I deem "basic" for this game:

-   Bouncy animations + dust particles when you hit stuff

-   Particle trails all around (showing your movement)

-   Unique sheep characters (one per player), perhaps with blinking eyes or something.

-   Some indicators for what you're doing. (Holding both buttons to float? What's your jump direction? What's the terrain doing to you?)

-   Sound effects for the most important actions

(Fortunately, I'd already created a soundtrack one inspired evening, which might actually turn out to be the best part of the game xD)

## Step 20: Finishing the items

When I returned to my item code, I didn't really understand what I was thinking at the time.

This is what it did:

-   Check our collision data each frame (a list of all things we collided with)

-   If it hits our world ( = TileMap node), register the position of that collision

-   Convert it to a position

-   Check the grid to see if there's an obstacle there

-   Check if we're coming from the right side (so we don't trigger things when it doesn't make sense)

-   Now activate it. (But add a timeout, so we don't re-activate each frame, but only once every X seconds.)

Yeah, this wasn't going to cut it anymore.

Instead, I found I already had an *Area* attached to each item (which is used for checking if a physics body is inside of it or not). Right now, this is only used by the "Timed Button" => you must stay connected to it for a few seconds before it activates.

Why did I use a separate system for that, instead of the default one above? Well, probably because I realized (during testing), that it was near impossible to actually *keep colliding with the floor for X seconds*. No, due to imprecision, due to randomness, you'll bounce up and down, roll left and right. So we need some margin: hence, an *area* around the block that detects the hit.

But ... we can just use this for most things! So I made the Area a general thing, and each unique item a "module" that can access it.

Why "most" things? Well, spikes (for example) *don't* benefit from this. They are a one-time thing: you hit them hard, get damage, and it's done. So those *should* check for an actual collision, instead of checking if you're "in their general area".

This means there were now 3 classes of items:

-   Immediate (like the spikes)

-   Ongoing (when hit, you get some powerup/status effect that stays for some time, then fades)

-   On/Off (while in the area, this effect is active, but when you leave it, it goes away)

This is a bit much. There's already enough happening in the game. Simplifying ...

-   I decided to **completely scrap** the "ongoing" idea. (There's nothing else in the game that "stays with you for a while (like a powerup)", so it doesn't fit anywhere.)

-   Immediate items are often *destroyed* once used. (Otherwise, you could run into the same spikes over and over if you're unlucky, which is just annoying and frustrating.)

It's amazing how you can come back to a project some months later, and just *don't understand at all what you were thinking*, and see easy ways to simplify and improve all the code.

Anyway, after some rewriting, this works great and is a way better (and more flexible) plan.

### Better items?

First of all, I renamed "items" to "special tiles" wherever I could. It's a way better description for what they are and what they do.

Secondly, once I implemented the *cannon* (shoots bullets across the room) and *laser* (has a constant death ray that ends at the next tile it hits), I immediately saw that those were *great* additions.

It just added so much to the gameplay. Suddenly, you couldn't just fly anywhere you want. You needed to time a jump to dodge a bullet. Or take the other way around to avoid the laser.

This was in stark contrast to how "useless" (or "disjointed") many of the other tiles felt. For example, I implemented a "shield" that makes you invincible while standing on it. But how often will that actually be useful?!

So I tried to think more along the lines of the cannon. Something that actually has a big influence on the main mechanic of the game, forcing you to roll differently. Slowly, I realized there were two main ways to get this effect:

-   Create stuff that blocks players. (But in a varied, temporary way. Otherwise it's the same as a *lock*, just, erm, worse.)

-   Create stuff that directly modifies physics, spaces, speed, the route, etc.

It dawned on me that the reason I found it a tad boring to play, is because the rooms looked samey after a while, and it was easy to *power through them* (if you aimed well).

What if I could create small "platforming sections" along the route? What if I could add *ramps*, *moving platforms, doors opening/closing?* It would change up the gameplay and prevent just floating through the whole thing.

What's holding me back? Well, the fact that we need *space* for this and the route has to be *finishable*. If I just add these elements anywhere, there's a good chance a situation is created that you just can't get through. It's useless adding a ramp, if there's no space above it to jump.

The only way I see this working, is if I can tell the algorithm to **create a big room and keep it empty** (no special tiles or things inside), and then have some **fast checks to ensure the route stays finishable.**

**This is something I can't (easily) figure out right now**. So I'm going to leave it, write it down as a future addition, and continue finishing the game.

Additionally, I decided to leave out the **shop** lock. I just couldn't make it work, without making it overly complicated and adding *another* system to the game. Again, ideas for it are written down for the future, but it won't be in the game.

Remember: this was supposed to be a "one week game" :p It's already way, way bigger than that and took longer.

### Feedback & Stuff

By now even *I* was sometimes confused what an item did exactly. (There are *so many things in the game*, and most of them don't have their tutorial image yet, or were made in 10 minutes and then forgotten by me :p)

Which made *feedback* the next priority + finishing all those tutorials. A looooot of feedback, because there are just so many things that can happen in this game.

I've learned (over the years) that it's best to do the "quartet of polishing" at the same time: feedback, particles, sound effects, and animations/tweens. So that's what I did.

(Why? Because they are (very) often *the same*. If something needs a sound effect, it probably also needs particles, an animation, and feedback. It's quite rare that something only needs *one* of those. By doing them simultaneously, I can be more productive.)

### Performance

Because the game blew up in size (unexpectedly), some of the code and the systems aren't performant enough anymore. After encountering numerous occasions where *lag* was noticeable, I decided I just had to rewrite some large parts of the code.

The main culprits?

-   Every script in the game finds and saves *its own reference* to other nodes it needs. (For example, the "Input" module has to relay its info to the "Movement" module to move the player. So, when the module is instantiated, it finds that module and saves the reference to it.) This means *thousands* of expensive node lookup calls.

-   When you hit the tilemap, it paints a splat on it. This is great for adding color, life, variation to the game. It also means I need a *humongous texture overlaying the whole tilemap, which is constantly updated*.

The first one is solved by simple restructuring. Instead of every module having its own references, each one has a reference to its parent. *Only the parent needs to lookup stuff.* (Although it's simple, it still took a lot of time, as I had to change this *absolutely everywhere*.)

The second one is harder. I'd need to: figure out which part of the playing area is actually being interacted with, resize the image constantly based on that information, and only update when necessary. *I don't know how to do this* *(well)*.

In the end, I decided to ...

-   Implement a "dirty" flag => only if something *actually changed* do we update this texture and send it to the shader again. (An easy improvement.)

-   Implement a "resolution" => fixes almost all lag, but obviously makes the paint a bit more pixelated/blurry (because we're scaling up a low-res image to fit the whole world)

    -   For example, a resolution of "2" would already mean the image size is cut in *half*. This means we go from 3200x1920 pixels to 1600x960 pixels, which is far easier for the average PC to handle.

-   Add a "performance mode" in the settings that turns off this whole system.

With these changes, even with all systems fully operational, I don't get any lag anymore!

## Step 21: Gameplay Polishing

So, I just spent a few days adding the feedback, the sound effects, the particles, etcetera. The "superficial polishing", so to speak. (Not any less important, but it doesn't impact gameplay or core mechanics, hence "superficial".)

There are many, *many* variables to tweak in this game. This step is always a bit overwhelming for me, unsure about every change I make (or don't make), but in general I just test the game a lot with different configurations and see what feels best.

For example: from the start of development, the rule "bigger shapes move faster" has been in the game.

But now, in the final game, I'm not so sure anymore. It's already enough of a *penalty* to have some unrollable triangle shape -- do I really need to penalize you even more with severely reduced speed?

At the same time, the rule was introduced because smaller shapes have an easier time fitting through gaps. And I don't want to reward players from being bad and decimating themselves, I want to reward them for staying big and alive! That's why they became slower.

In the end, it usually leads to a compromise. The rule is still in the game, but its effect is weakened. So much in fact, that I don't explain it in the tutorial anymore.

Within a few days, I try to make hundreds of these tiny decisions, hopefully for the better :)

**When in doubt, I choose the option that simplifies the game (less to explain to players, less to remember, etcetera) or that saves me work.** Again, that's the mindset I've acquired after years of making games, a practical one that *gets stuff done*.

### Solo Mode

For the longest time, I completely forgot I planned to have a solo mode in this game. When I remembered, I wrote down a quick idea for it, then forgot again.

Well, with the game as good as done, now this mode should *really* be implemented :p

The idea is the same as most games that feature racing (in side-view):

-   The level is slowly fading away behind you. (Some ... thing is chasing you at a constant speed, anything it passes is destroyed.)

-   If it catches up to you, you are destroyed as well, thus losing the game.

However, my game doesn't have a fixed and easy direction. (Always left to right, for example.) The route can literally go anywhere.

How do we handle this?

-   Create a rectangle and start it at the last room. (As soon as the player leaves it, of course, otherwise they die instantly.)

-   Resize it to match the size of this room (so it fits nicely on top of it).

-   Move in the forward direction -- I've saved this on every room, as I also need it for other components of the generation -- with a fixed speed.

-   Whenever we enter a new room, completely destroy the previous one.

-   If the rectangle overlaps the player? You lose.

-   (The player finishes before dying? You win!)

It won't look that pretty and polished, but it should be a strong solo mode.

(Which is a must-have in local multiplayer games! If your game *only* supports 2+ players, it's way less likely to be bought/tried. Because people can't test if they like the game on their own, they can't play the game at all when nobody else is around or they're still waiting on their guests, it's just too restrictive.)

I can even speed up the pace if you're far ahead, or slow down if it's about to hit you, to balance the game for the skill of the player.

### Quality of Life

When I went away from this project, I made a game where **outlines** made all the difference. So I decided to port that code to this game as well, and it (again) made all the difference! Simply drawing a (thick, dark) outline around all shapes made the game *much* easier to parse and play.

Similarly, there was a limit of **5 bodies** per player. But this was just too much. **3 or 4 bodies (at most)** is better and, again, easier to deal with.

I also observed some *patterns* that were hard to overcome.

For example, if the entrance to the next room was *one higher* than a slope, it was really annoying to reach. (As you can't roll there, but a jump would likely take you too high.)

I think it'd make a huge difference if I could *identify these "annoying" patterns* and build something to help players overcome them. (In this case: just remove the block that's preventing a nice rolling entry, or add some *magnet* to the opening that draws you into it.)

### Things that should've been fixed long ago

Over time, problems start to add up (in a project) that you just don't know how to solve, and which are just annoying.

Well, with the game being as good as done, it was time to fix those issues. Luckily, after some time away, the solutions were easier to find.

### Teleporters

**Teleporters:** if the random generation is stuck (happens sometimes, especially on large player counts), it places a teleporter in its last room. Once all players reached it, the map is erased, and you start again somewhere else.

The problem? The teleporter needs to be *big*. Otherwise it doesn't fit, it's hard to see it (and enter it), and it's a mess.

But ... if you're stuck, there's a 90% chance the last room is 1x1 room somewhere in a corner.

My first solution was to blow up that last room. Just make it bigger, turn it into a teleporter.

The problem? This might cause it to overlap older parts of the path, ruining everything! (Or it might go out of bounds, also leading to a crash.)

I *could* write complicated code to check this, but I thought of something better instead.

When a teleporter must be placed, just **look back at the last 10 rooms. Pick the biggest one; place it there.** (There's a 100% chance a decently sized one is among the last 10 rooms.)

To make life even easier, I also decided to be careful and already place a teleporter when I *think* we're about to run out. (So when the number of valid rooms is very low, below 10 or so.) Would speed up generation and lead to prettier routes.

### Lock problems

There were three major issues:

-   Only *completely open connections* are opened when you unlock a lock. Any opening that leads to a *slope*, for example, remains closed now. Which is ... confusing and unnecessarily constricting.

-   Many minigames require complete access to the room. At the moment, there is *some* chance there are holes you cannot reach, which is a big no-no.

-   The text labels (that give information about your progress) were all over the place. (Some were placed *outside* the lock, or *behind* something, or initialized to a random number.)

**Solution #1?** Look up the indices in the tilemap of slopes (or other half-open tiles). Also count those as "free" or "open" in the algorithm.

**Solution #2?** After randomly placing tiles, check for any tile that is *empty* ... yet surrounded by only filled tiles. That is a *hole*. Fill it.

**Solution #3?** Create a general scene for the label, use that everywhere, and initialize it properly. (I decided to initialize to a question mark, *until* you interact with the lock. Adds some more mystery.)

## Step 22: Walking back bad decisions

Earlier I mentioned the following rule: "whenever something happens to *one body*, it should happen to *all of your bodies*"

Although a good idea in theory, it didn't work in practice. It just becomes confusing, way too hard to keep track of. If I'd wanted to do this, I should've kept it in mind (and supported it) right from the beginning.

The rule was designed to make the fact that you can be split into multiple bodies *more useful/impactful*.

So, we need something else to achieve the same thing. At the same time, I observed these flaws:

-   Coins aren't used enough. There should be *way more items* where you can pay coins in exchange for ... something good.

-   There should be some more control over growing/shrinking in actual *size*. (Now it's often a *bad* thing if you become big and powerful, because you don't fit through all gaps anymore.)

-   We still need more platforming elements in the game

As such, I decided to add more special tiles to the game (with a high probability of appearing) aimed specifically to solve these 4 problems.

**Multiple bodies?**

-   A tile that gives you as many coins as you have bodies.

-   A tile that freezes bodies nearby *if they aren't your worst body*.

    -   This might seem an obstacle, but it's actually a helpful thing.

    -   It locks a body, so you can safely move your others without worrying about it.

-   A tile that changes *all your bodies* to a triangle.

    -   The one tile that **does** have its effect on **all** your bodies

**Coins?** (So these act as a sort of "shop".)

-   Pay X coins to destroy all your other bodies.

-   Pay X coins to *blast away* or *slice* all nearby bodies (excluding your own, of course).

-   Pay X coins for a huge time bonus (solo_unpickable)

-   Pay X coins to *shrink* (+ *make triangle)* everyone around you

**Growing/Shrinking**

-   A tile that grows you to max size

-   A tile that shrinks you to min size

**Platforming?**

-   A magnet that attracts/repels all bodies in a radius (ignoring walls)

-   A platform placed somewhere in the room that simply turns on/off on a timer. (Acting like a door, or gate, or moving floor, depends on situation.)

-   A similar platform that *moves* or has a *hole* in it.

-   An item that just has a *slight* slope on it, causing you to roll/fly off, without blocking too much.

Yes, this adds *even more content*, and doesn't entirely solve the core issues. But I feel done with the game and don't want to do a core rewrite.

(Another bad decision was: "when you hit another body of yours, all coins are transferred to the biggest shape" It's often impossible to tell which one is actually bigger. There's no real use for this. When it happened for the first time, *I* was confused for a moment -- and I made the game! So this was simply turned off.)

(Additionally, the max number of coins was scaled back from 10 to 5. Again, too hard to keep track of more than that, and it polluted the visuals.)

## I think I'll stop here

There were many, many, many minor (or sometimes surprisingly major) things I had to fix. Bugs that crashed the generation, annoyances that would make it (near) impossible to progress in certain situations, stuff that needed to be balanced (otherwise it was just too hard and you needed to much skill to do something).

It took a few days (of continuous work) more than I wanted, but in the end we got there. And so I'll stop this devlog here. Because I am *done* with this game and need a rest :p

## Step 23: Final Playtest

But I'm a professional! I'm not launching a (paid) game without doing the playtesting and ensuring it's good enough. (Or well, I *try* to be a professional.)

So I did. The good news? Players had tons of fun, after some practice they got the hang of the movement and were able to actually make it a competition, in general the game works.

There were quite some bugs (which only revealed itself during chaotic testing with many players) I had to address. There was a single crash. (Which is more than you like, obviously, but usually just means some stupid error I can easily spot in an old piece of code.)

The main issues?

-   With many players, of ... varying skill levels, the camera zooms out *a lot*. Making stuff small and hard to see. Solution? Find ways to keep the camera more zoomed in and stuff bigger. (Less distance allowed between you and leading player. Scale tutorial images with screen size, now they are constant. Place locks more frequently or take longer to solve them.)

-   Players had issues with jumping. To make jumping more varied and useful (especially to myself, an experienced player) I modify the jump direction based on the angle of what you're standing on. But to new players ... they just expect to jump straight up. Solution? Make it so :p Make the other an "export option" you can turn on.

Otherwise, there were many tiny bugs, most of them easy to fix or just a hilarious mistake. (I'd rewritten the code for sorting players based on their finish time, to make it faster *and* account for some special powerups I added last minute. But in doing so, I'd reversed the order ... so the worst player came first xD)

In general, if my to-do list after a playtest (of an hour long) is short/simple enough to finish in a day, that's a good sign. It means 99% of the game just works well and players had enough fun that I'm not doubting myself or the core of the game.

So let's do that, create a trailer/marketing material for it, then we can call it done.

## Conclusion

Do I like the game? Yes. I think it turned out well, albeit much different from the original plan.

Many elements are something I've never seen before in a game, or never made myself before, which means it was *at least* a great learning experience that added some new tools for my tool belt.

But besides that, it's just a game that's

-   Extremely easy to pick up and play. (Reach the finish first. Roll left/right to do this.)

-   Has a great new tutorial system that works wonders. (Everything is taught *inside the level*, *right before you need it*. Basically removing the need for any upfront tutorials or boring "reading a wall of text with a group of people who just wanna play a game")

-   And looks colorful, fun, juicy, varied, like a real party game.

Is it perfect? Nope. Only once I was finishing up the project, did I realize what I actually needed.

-   More platforming sections, created by randomly placed items. Now we only have some basics: a trampoline, a cannon with bullets to dodge, some slopes and simple platforms.

-   More *items* that use the coin system. (In fact, the coin system is *fine*, but not *great*, and I might have entirely removed it if I could.)

-   More stuff that's applicable when playing in *solo mode*. (I realized I had to scrap a lot of terrains/items because they only did something useful when you have 2+ players.)

-   More variation in the level generation, both in visuals (it only uses a basic tileset, no extra flowers, or variations, or whatever) and by pattern-matching situations that are annoying to players.

I've written all of these as a "future to do". I think this game would get a huge boost (in content and fun) with these additions, but I just don't have any more time to spare on this project. It was supposed to be a "one week game" (OWG), now it's a "three week game", and I really don't want to blow it up any further.

(Additionally, it was set up as a small project, which means increasing scope wouldn't work well, as the code and systems just aren't there to support it.)

Additionally, being a OWG, the plan was to release it for free. However, the amount of work I put in, the quality of the final product, the fact that I learned putting a price tag on your work is generally the way to go ... steered me towards making it a paid release.

So that's what I did. Finished another project, it became better than I anticipated (but still some way from a big professional release), now onto the next one.

Until the next devlog,

Pandaqi
