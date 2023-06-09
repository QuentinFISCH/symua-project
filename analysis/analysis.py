import pynetlogo
import pandas as pd
import numpy as np

import itertools
from math import pi

import matplotlib.pyplot as plt
import seaborn as sns
from multiprocessing import Pool
from matplotlib.legend_handler import HandlerPatch


from SALib.sample import sobol as sobolsample
from SALib.analyze import sobol

# Taken in pynetlogo documentation
# https://pynetlogo.readthedocs.io/en/latest/

NETLOGO_HOME = "../dependencies/NetLogo 6.3.0/"
MODEL_PATH = "bees.nlogo"

problem = {
    "num_vars": 4,
    "names": [
        "num-bees-per-hive",
        "flower-density",
        "num-hives",
        "scout-radius",
    ],
    "bounds": [
        [1, 100],
        [0.0, 1.0],
        [1, 10],
        [3, 40],
    ],
}

param_values = sobolsample.sample(problem, 256, calc_second_order=True)
experiments = pd.DataFrame(param_values, columns=problem["names"])


def initializer(netlogo_path, modelfile):
    global netlogo

    netlogo = pynetlogo.NetLogoLink(gui=False, thd=False, netlogo_home=netlogo_path)
    netlogo.load_model(modelfile)


def run_simulation(experiment):
    for key, value in experiment.items():
        if key == "random-seed":
            netlogo.command("random-seed {}".format(value))
        else:
            netlogo.command("set {0} {1}".format(key, value))

    netlogo.command("setup")
    counts = netlogo.repeat_report(
        ["count turtles", "plot-total-pollen", "get-flower-pollen"], 1000
    )

    result = pd.Series(
        [
            counts["count turtles"].mean(),
            counts["plot-total-pollen"].mean(),
            counts["get-flower-pollen"].mean(),
        ],
        index=["Avg. turtles", "Avg. total-pollen", "Avg. flower-pollen"],
    )

    return result

# from tqdm import tqdm

# initializer(NETLOGO_HOME, MODEL_PATH)
# results = []
# for experiment in tqdm(experiments.to_dict("records")):
#     results.append(run_simulation(experiment))
# results = pd.DataFrame(results)

print("Running experiments...")
with Pool(14, initializer=initializer, initargs=(NETLOGO_HOME, MODEL_PATH)) as executor:
    results = []
    for entry in executor.map(run_simulation, experiments.to_dict("records")):
        results.append(entry)
    results = pd.DataFrame(results)
print("Done.")

Si = sobol.analyze(
    problem,
    results["Avg. turtles"].values,
    calc_second_order=True,
    print_to_console=False,
)

Si_filter = {k: Si[k] for k in ["ST", "ST_conf", "S1", "S1_conf"]}
Si_df = pd.DataFrame(Si_filter, index=problem["names"])


def normalize(x, xmin, xmax):
    return (x - xmin) / (xmax - xmin)


def plot_circles(ax, locs, names, max_s, stats, smax, smin, fc, ec, lw, zorder):
    s = np.asarray([stats[name] for name in names])
    s = 0.01 + max_s * np.sqrt(normalize(s, smin, smax))

    fill = True
    for loc, name, si in zip(locs, names, s):
        if fc == "w":
            fill = False
        else:
            ec = "none"

        x = np.cos(loc)
        y = np.sin(loc)

        circle = plt.Circle(
            (x, y),
            radius=si,
            ec=ec,
            fc=fc,
            transform=ax.transData._b,
            zorder=zorder,
            lw=lw,
            fill=True,
        )
        ax.add_artist(circle)


def filter(sobol_indices, names, locs, criterion, threshold):
    if criterion in ["ST", "S1", "S2"]:
        data = sobol_indices[criterion]
        data = np.abs(data)
        data = data.flatten()  # flatten in case of S2
        # TODO:: remove nans

        filtered = [
            (name, locs[i]) for i, name in enumerate(names) if data[i] > threshold
        ]
        filtered_names, filtered_locs = zip(*filtered)
    elif criterion in ["ST_conf", "S1_conf", "S2_conf"]:
        raise NotImplementedError
    else:
        raise ValueError("unknown value for criterion")

    return filtered_names, filtered_locs


def plot_sobol_indices(sobol_indices, criterion="ST", threshold=0.01):
    """plot sobol indices on a radial plot

    Parameters
    ----------
    sobol_indices : dict
                    the return from SAlib
    criterion : {'ST', 'S1', 'S2', 'ST_conf', 'S1_conf', 'S2_conf'}, optional
    threshold : float
                only visualize variables with criterion larger than cutoff

    """
    max_linewidth_s2 = 15  # 25*1.8
    max_s_radius = 0.3

    # prepare data
    # use the absolute values of all the indices
    # sobol_indices = {key:np.abs(stats) for key, stats in sobol_indices.items()}

    # dataframe with ST and S1
    sobol_stats = {key: sobol_indices[key] for key in ["ST", "S1"]}
    sobol_stats = pd.DataFrame(sobol_stats, index=problem["names"])

    smax = sobol_stats.max().max()
    smin = sobol_stats.min().min()

    # dataframe with s2
    s2 = pd.DataFrame(
        sobol_indices["S2"], index=problem["names"], columns=problem["names"]
    )
    s2[s2 < 0.0] = 0.0  # Set negative values to 0 (artifact from small sample sizes)
    s2max = s2.max().max()
    s2min = s2.min().min()

    names = problem["names"]
    n = len(names)
    ticklocs = np.linspace(0, 2 * pi, n + 1)
    locs = ticklocs[0:-1]

    filtered_names, filtered_locs = filter(
        sobol_indices, names, locs, criterion, threshold
    )

    # setup figure
    fig = plt.figure()
    ax = fig.add_subplot(111, polar=True)
    ax.grid(False)
    ax.spines["polar"].set_visible(False)

    ax.set_xticks(locs)
    ax.set_xticklabels(names)

    ax.set_yticklabels([])
    ax.set_ylim(top=1.4)
    legend(ax)

    # plot ST
    plot_circles(
        ax,
        filtered_locs,
        filtered_names,
        max_s_radius,
        sobol_stats["ST"],
        smax,
        smin,
        "w",
        "k",
        1,
        9,
    )

    # plot S1
    plot_circles(
        ax,
        filtered_locs,
        filtered_names,
        max_s_radius,
        sobol_stats["S1"],
        smax,
        smin,
        "k",
        "k",
        1,
        10,
    )

    # plot S2
    for name1, name2 in itertools.combinations(zip(filtered_names, filtered_locs), 2):
        name1, loc1 = name1
        name2, loc2 = name2

        weight = s2.loc[name1, name2]
        lw = 0.5 + max_linewidth_s2 * normalize(weight, s2min, s2max)
        ax.plot([loc1, loc2], [1, 1], c="darkgray", lw=lw, zorder=1)

    return fig


class HandlerCircle(HandlerPatch):
    def create_artists(
        self, legend, orig_handle, xdescent, ydescent, width, height, fontsize, trans
    ):
        center = 0.5 * width - 0.5 * xdescent, 0.5 * height - 0.5 * ydescent
        p = plt.Circle(xy=center, radius=orig_handle.radius)
        self.update_prop(p, orig_handle, legend)
        p.set_transform(trans)
        return [p]


def legend(ax):
    some_identifiers = [
        plt.Circle((0, 0), radius=5, color="k", fill=False, lw=1),
        plt.Circle((0, 0), radius=5, color="k", fill=True),
        plt.Line2D([0, 0.5], [0, 0.5], lw=8, color="darkgray"),
    ]
    ax.legend(
        some_identifiers,
        ["ST", "S1", "S2"],
        loc=(1, 0.75),
        borderaxespad=0.1,
        mode="expand",
        handler_map={plt.Circle: HandlerCircle()},
    )


def plot_sobol(param, output):
    Si = sobol.analyze(
        problem,
        results[param].values,
        calc_second_order=True,
        print_to_console=False,
    )

    sns.set_style("whitegrid")
    fig = plot_sobol_indices(Si, criterion="ST", threshold=0.005)
 
    fig.set_size_inches(7, 7)
    plt.savefig(output)

plot_sobol("Avg. turtles", "turlesobol.png")
plot_sobol("Avg. total-pollen", "pollensobol.png")
plot_sobol("Avg. flower-pollen", "flowersobal.png")
netlogo.kill_workspace()