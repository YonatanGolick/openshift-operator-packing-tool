"""
All rights reserved to Dave™
"""
import argparse
import os


def get_args():
    """
    This simple tool was created to help teams upload whitened images to their
    registry inside the secured environment.
    This tool assumes you are working with images that are already formatted to
    fit skopeo, if they are not it will not work without modifications.
    All rights reserved to Dave™
    """
    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description='Process args for usage in the script')
    parser.add_argument(
        '--registry', type=str, required=True,
        help='Remote registry to push the images into')
    parser.add_argument(
        '--local', type=str, required=True, default="registry:5000",
        help='The local registry you are copying from')
    parser.add_argument(
        '--user', required=True,
        help='User name to use when connecting to host')
    parser.add_argument(
        '--password', required=True,
        help='Password to use when connecting to host')
    parser.add_argument(
        '--image-list', type=str, required=True,
        help='The location of the image list to copy')
    parser.add_argument(
        '--dry-run', required=False, default=False, action='store_true',
        help='Dry run your image copying process')
    args = parser.parse_args()
    return args

def main():
    """
    All rights reserved to Dave™
    """
    args = get_args()
    images_temp = open(args.image_list, "r")
    images = images_temp.read()
    images = images.split('\n')
    images.remove('')
    if args.dry_run:
        action = 'echo skopeo copy -a --dest-tls-verify=false'
    else:
        action = 'skopeo copy -a --dest-tls-verify=false'
    for image in images:
        remote_registry = image.replace(args.local, args.registry)
        os.system('%s %s %s' % (action, image, remote_registry))


if __name__ == "__main__":
    main()
