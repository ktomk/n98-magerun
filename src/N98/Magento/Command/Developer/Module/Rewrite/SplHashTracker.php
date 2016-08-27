<?php
/**
 * Created by PhpStorm.
 * User: mot
 * Date: 27.08.16
 * Time: 12:36
 */

namespace N98\Magento\Command\Developer\Module\Rewrite;


class SplHashTracker
{
    private static $hashes;

    /**
     * @param $object
     * @return string
     */
    public static function hash($object)
    {
        $hash = spl_object_hash($object);
        if (isset(self::$hashes[$hash])) {
            $index = self::$hashes[$hash];
        } else {
            self::$hashes[$hash] = $index = count(self::$hashes);
        }

        $colors = array('red', 'green', 'blue', 'pink', 'purple', 'black');
        if (isset($colors[$index])) {
            $color = $colors[$index];
        } else {
            $color = '#' . $index;
        }

        return $color . ' ' . $hash;
    }
}
